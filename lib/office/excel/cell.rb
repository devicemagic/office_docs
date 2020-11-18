require 'date'

module Office
  # depends on a method styles
  module CellNodes
    # xlsx stores all datetime and time numerical values relative to utc offset
    UTC_OFFSET_HOURS = DateTime.now.offset
    DATE_TIME_EPOCH = DateTime.new(1900, 1, 1, 0, 0, 0) - 2
    TIME_EPOCH = Time.new(1900, 1, 1, 0, 0, 0) - 2
    DATE_EPOCH = Date.new(1900, 1, 1) - 2

    # return  sequential index of num_fmt_id. 0 if not found
    # TODO lazily create styles?
    def self.style_index styles, num_fmt_id
      styles.index_of_xf(num_fmt_id) || 0
    end

    def self.build_c_node target_node, obj, styles:, string_table: nil
      raise 'must be a c node' unless target_node.name == ?c

      # create replacement node for different types
      case obj

      when NilClass
        # remove all content children
        target_node.children.unlink

        # remove all attributes except r which specifies A1 reference
        target_node.attribute_nodes.each{|attr| attr.unlink unless attr.name == ?r}

      when true, false
        target_node.children = target_node.document.create_element 'v', (obj ? ?1 : ?0)
        target_node[:t] = ?b
        target_node[:s] ||= style_index(styles, 165) # boolean style used by localc, not sure if that applies to other spreadsheet apps.

      # TODO xlsx specifies type=d, but Excel and LibreOffice seem to rely on t=n with a date style format
      when DateTime
        # .floor because xlsx specification only allows for precision of 1/86400, which is the number of seconds in a day.
        # Except for leap seconds...?
        floored = DateTime.new obj.year, obj.month, obj.day, obj.hour, obj.minute, obj.second.floor, obj.offset
        # Float otherwise it's a Rational
        days_since_epoch = Float floored - (DATE_TIME_EPOCH - UTC_OFFSET_HOURS)
        target_node.children = target_node.document.create_element 'v', days_since_epoch.to_s
        # It's a bit weird that there is a ?d in the spec for dates, but it's not used.
        target_node[:t] = ?n
        target_node[:s] ||= style_index(styles, 22) # default/generic datetime

      when Time
        # TODO same as DateTime except style number is different
        # .floor because xlsx specification only allows for precision of 1/86400
        # Float otherwise it's a Rational
        span = Float obj.floor.to_datetime - (DATE_TIME_EPOCH - UTC_OFFSET_HOURS)
        target_node.children = target_node.document.create_element 'v', span.to_s
        # It's a bit weird that there is a ?d in the spec for dates, but it's not used.
        target_node[:t] = ?n
        target_node[:s] ||= style_index(styles, 21) # default/generic time hh::mm::ss

      when Date
        # Integer otherwise it's a Rational
        span = Integer obj - DATE_EPOCH
        target_node.children = target_node.document.create_element 'v', span.to_s
        target_node[:t] = ?n
        target_node[:s] ||= style_index(styles, 14) # default/generic date

      when String
        if string_table
          string_table_index = Integer(value_node.text)
          raise "Wrongly does not do copy-on-write"
          # This is the <si><t>...</t></si> node in the string table
          v_t_node = string_table.node.children[string_table_index].children.first
          # replace the children, ie the text content of <t>
          v_t_node.children = obj.to_s

          # TODO set style and type

          # TODO will probably be needed
          # string_table.invalidate string_table_index
        else
          # clear children
          target_node.children = ''
          # need a <is><t> ... structure
          # must NOT have a v
          Nokogiri::XML::Builder.with target_node do
            is do
              t obj.to_s
            end
          end
          target_node[:t] = 'inlineStr'
          target_node[:s] ||= style_index(styles, 0) # general style

        end

      when Float
        target_node.children = target_node.document.create_element 'v', obj.to_s
        target_node[:t] = ?n
        target_node[:s] ||= style_index(styles, 0) # general

      when Integer
        target_node.children = target_node.document.create_element 'v', obj.to_s
        target_node[:t] = ?n
        target_node[:s] ||= style_index(styles, 1) # general

      else
        raise "dunno how to convert #{obj.inspect}"

      end

      target_node
    end
  end

  class Cell
    include CellNodes

    attr_reader :node
    attr_reader :string_table
    attr_reader :styles

    # TODO in some cases we may be able to optimise this, since cell is
    # constructed from a location, eg in Sheet#[] which already has a
    # location and the location was used to find the node.
    # So maybe a location: nil keyword
    def initialize(c_node, string_table, styles)
      @node = c_node
      @string_table = string_table
      @styles = styles
    end

    def data_type
      # convert to symbol now because it's 10x faster for comparisons later
      @data_type ||= node[:t]&.to_sym
    end

    def style_id
      # this defines date/int/string format (presumably as well as colour and bold/italic/underline etc?)
      @style_id ||= node[:s].to_i
    end

    def location
      @location ||= Location.new node[:r]
    end

    def style
      @style ||= styles&.xf_by_id(style_id)
    end

    def shared_string
      @shared_string ||= begin
        if string? && value_node
          string_id = Integer value_node.content
          str = string_table.get_string_by_id(string_id)
          str or raise PackageError, "Excel cell #{location} refers to invalid shared string #{string_id}"

          # why? maybe for invalidation? surely copy-on-write would work better?
          str.add_cell(self)

          str
        end
      end
    end

    def value_node
      # Originally did this, but was incredibly slow:
      #@value_node = node.at_xpath("xmlns:v")
      # As of 30-Oct-2020, the difference seems to be that at_xpath is about 15x slower than find
      # find     2.7548958314582705e-06
      # at_xpath 4.0650357003323730e-05
      # at_css      5.8584785833954814e-05

      # fastest
      # TODO does not handle inline strings
      @value_node ||= node.elements.find { |e| e.name == 'v' }
    end

    def stringtable_node
      shared? && @stringtable_node ||= string_table.node.children[]
    end

    def is_string?
      shared? || inline?
    end

    alias string? is_string?

    def shared?
      data_type == :s
    end

    def inline?
      data_type == :inlineStr
    end

    def to_ruby
      formatted_value
    end

    # Set the value of this cell from the ruby value
    # makes an effort to replace the node contents only (ie the c node itself does not change)
    # makes an effort to be atomic, so partial failures will make no change.
    def value= obj, inline_string: true
      # build the node completely before replacing it
      save_node = node.dup

      # clear node
      node.children.unlink

      # rebuild
      CellNodes.build_c_node node, obj, styles: styles, string_table: (!inline_string && string_table)

      # reset memos
      @value_node = nil
      @data_type = nil
      @style_id = nil
      remove_instance_variable :@placeholder if instance_variable_defined? :@placeholder
    rescue
      # restore partially built node
      node.children = save_node.children
      raise
    end

    # contains the first placeholder. There might be more than one.
    def placeholder
      # to invalidate this, use remove_instance_variable
      if instance_variable_defined? :@placeholder
        @placeholder
      else
        placeholder = case
        when shared?
          to_ruby

        when inline?
          # TODO should dig down to the actual <t> cell; and handle text runs
          node.text

        # Formulas do this, so maybe the formula has a string value
        when data_type = 'str'
          self.value

        end

        @placeholder =
        if placeholder
          placeholder =~ /\{\{(.*?)\}\}/
          $1
        end
      end
    end

    def empty?; !value end

    def self.create_node(document, row_number, index, value, string_table, styles:)
      cell_node = document.create_element('c')
      cell_node[:r] = Location[index, row_number-1] # NOTE row_number not row_index

      # TODO pass string_table. Right now we're just using inline
      CellNodes.build_c_node cell_node, value, styles: styles
      cell_node
    end

    # TODO I think there need to be (at least) two value accessors:
    #
    # to represent ruby values (maybe #value, or #to_ruby)
    #   1) enum Ruby = String | Float | Integer | Boolean | Date | Time | DateTime | Nil
    #
    # and to represent the <c t=> values (maybe #content, because it's what's inside the cell or ml_value for Markup Language Value)
    #  2) enum cell_value = Boolean(v) | Date(integer_seconds|float_seconds) | Error(msg) | InlineString(str) | Number(n) | SharedString(str) | FormulaStr(str)
    #
    # formatted_value conflates formatting with type, especially Date & Time
    # and it's really a ui_value, or display_value which effectively truncates precision.
    # But formatted_value contains important type information.
    def value
      # binding.pry if shared? && shared_string.node.text != shared_string.text

      # shared? ? shared_string.text : value_node&.content
      # shared? ? shared_string.node.text : value_node&.text
      # when shared_string.node has runs, this breaks
      if string?
        case
        when shared?
          # TODO this does not handle runs in shared strings
          shared_string.text

        when inline?
          # TODO I think this doesn't handle runs
          node.xpath('xmlns:is/xmlns:t').text

        else
          raise 'This is a non-shared, non-inline string...?'
        end
      else
        value_node&.content
      end
    end

    # Again running into conflation of the type/object and the format
    def formatted_value
      return shared_string.node.text if shared?
      return value if inline?

      unformatted_value = value
      return nil unless unformatted_value

      # for no style, determine type from the data_type attribute
      if style&.apply_number_format != '1'
        return case data_type
        when :n
          Integer unformatted_value rescue Float unformatted_value

        # NOTE this is specification-compliant, but really don't know if this will actually work
        when :d
          Time.iso8601 unformatted_value

        when :b
          case unformatted_value
          when ?1; true
          when ?0; false
          else
            raise "Unknown boolean value #{unformatted_value}"
          end

        else
          # TODO not sure this is the best way to convert to Numeric then fall back to String
          Integer unformatted_value rescue Float unformatted_value rescue unformatted_value
        end
      end

      # multi-value whens are faster. And we might need the type metadata somewhere else.
      # ECMA-376 Part 1 section 18.8.30 numFmt (Number Format) - p1767
      case style&.number_format_id&.to_i
      when 0  #    General
        as_decimal(unformatted_value)
      when 1  #    0
        as_integer(unformatted_value)
      when 2  #    0.00
        as_decimal(unformatted_value)
      when 3  #    #,##0
        as_integer(unformatted_value)
      when 4  #    #,##0.00
        as_decimal(unformatted_value)
      when 9  #    0%
        as_decimal(unformatted_value)
      when 10 #    0.00%
        as_decimal(unformatted_value)
      when 11 #    0.00E+00
        as_decimal(unformatted_value)
      # These are Rational
      #when 12 #    # ?/?
      #when 13 #    # ??/??
      when 14 #    mm-dd-yy
        as_date(unformatted_value)
      when 15 #    d-mmm-yy
        as_date(unformatted_value)
      when 16 #    d-mmm
        as_date(unformatted_value)
      when 17 #    mmm-yy
        as_date(unformatted_value)
      when 18 #    h:mm AM/PM
        as_time(unformatted_value)
      when 19 #    h:mm:ss AM/PM
        as_time(unformatted_value)
      when 20 #    h:mm
        as_time(unformatted_value)
      when 21 #    h:mm:ss
        as_time(unformatted_value)
      when 22 #    m/d/yy h:mm
        as_datetime(unformatted_value)
      when 37 #    #,##0 ;(#,##0)
        as_decimal(unformatted_value)
      when 38 #    #,##0 ;[Red](#,##0)
        as_decimal(unformatted_value)
      when 39 #    #,##0.00;(#,##0.00)
        as_decimal(unformatted_value)
      when 40 #    #,##0.00;[Red](#,##0.00)
        as_decimal(unformatted_value)
      when 45 #    mm:ss
        as_time(unformatted_value)
      when 46 #    [h]:mm:ss
        as_time(unformatted_value)
      when 47 #    mmss.0
        as_time(unformatted_value)
      when 48 #    ##0.0E+0
        as_decimal(unformatted_value)
      #when 49 #    @
      else
        unformatted_value
      end
    end

    def inspect
      "#{location.inspect} \"#{to_ruby}\""
    end

    # should probably be lambdas in a lookup, or clauses in the case
    private def as_decimal(value)
      value.to_f
    end

    private def as_integer(value)
      value.to_i
    end

    private def as_datetime(value)
      # Use round and convert to Rational here because we're compensating for
      # float precision errors, rather than representing an external date to the
      # specified precisions (1/86400)
      value = (value.to_f * 86400r).round / 86400r
      (DATE_TIME_EPOCH + value - UTC_OFFSET_HOURS).new_offset(UTC_OFFSET_HOURS)
    end

    private def as_date(value)
      DATE_EPOCH + value.to_i
    end

    private def as_time(value)
      as_datetime(value).to_time
    end
  end
end
