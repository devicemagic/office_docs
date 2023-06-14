module Word
  class PlaceholderFinder
    class << self
      #
      #
      # =>
      # => Getting placeholders
      # =>
      #
      #

      def get_placeholders(paragraphs)
        paragraphs.flat_map.with_index do |p, i|
          get_placeholders_from_paragraph(p, i)
        end
      end

      def get_placeholders_from_paragraph(paragraph, paragraph_index)
        loop_through_placeholders_in_paragraph(paragraph, paragraph_index).to_a
      end

      #
      #
      # =>
      # => Magical placeholder looping stuff
      # =>
      #
      #


      def loop_through_placeholders_in_paragraph(paragraph, paragraph_index)
        Enumerator.new do |yielder|
          runs = paragraph.runs
          run_texts = runs.map(&:text).dup

          run_texts.each_with_index do |run_text, i|
            next if run_text.nil?

            run_text.each_char.with_index do |char, j|
              next_char = next_char(run_texts, i, j)[:char]
              if char == '{' && (next_char == '{' || next_char == '%')
                beginning_of_placeholder = {run_index: i, char_index: j}
                end_of_placeholder = get_end_of_placeholder(run_texts, i, j)
                placeholder_text = get_placeholder_text(run_texts, beginning_of_placeholder, end_of_placeholder)

                placeholder = {
                  placeholder_text: placeholder_text,
                  paragraph_object: paragraph,
                  paragraph_index: paragraph_index,
                  beginning_of_placeholder: beginning_of_placeholder,
                  end_of_placeholder: end_of_placeholder
                }

                yielder << placeholder
              end
            end
          end
        end
      end

      def get_end_of_placeholder(run_texts, current_run_index, start_of_placeholder)
        placeholder_text = ""
        start_char = start_of_placeholder

        run_texts[current_run_index..-1].each_with_index do |run_text, i|
          next if run_text.nil? || run_text.empty?

          run_text[start_char..-1].each_char.with_index do |char, j|
            the_next_char = next_char(run_texts, current_run_index + i, start_char + j)
            if (char == '%' || char == '}') && the_next_char[:char] == '}'
              return {run_index: the_next_char[:run_index], char_index: the_next_char[:char_index]}
            else
              placeholder_text += char
            end
          end

          start_char = 0
        end

        raise InvalidTemplateError.new("Template invalid - end of placeholder }} missing for \"#{placeholder_text}\".")
      end

      def next_char(run_texts, current_run_index, current_char_index)
        current_run_text = run_texts[current_run_index]
        blank = {run_index: nil, char_index: nil, char: nil}
        return blank if current_run_text.nil?

        text = current_run_text || ""
        if text.length - 1 > current_char_index #still chars left at the end
          return {run_index: current_run_index, char_index: current_char_index + 1, char: text[current_char_index + 1]}
        else
          run_texts[current_run_index+1..-1].each_with_index do |run_text, i|
            next if run_text.nil? || run_text.empty?
            return {run_index: current_run_index+1+i, char_index: 0, char: run_text[0]}
          end
          return blank
        end
      end

       # This refactored version of the code uses map and join to simplify the code and make it more readable. It also removes the unnecessary result variable.
       def get_placeholder_text(run_texts, beginning_of_placeholder, end_of_placeholder)
        first_run_index = beginning_of_placeholder[:run_index]
        last_run_index = end_of_placeholder[:run_index]

        if first_run_index == last_run_index
          run_texts[first_run_index][beginning_of_placeholder[:char_index]..end_of_placeholder[:char_index]]
        else
          (first_run_index..last_run_index).map do |run_i|
            text = run_texts[run_i]
            next if text.nil? || text.empty?

            if run_i == first_run_index
              text[beginning_of_placeholder[:char_index]..-1]
            elsif run_i == last_run_index
              text[0..end_of_placeholder[:char_index]]
            else
              text
            end
          end.join
        end
      end
      
    end
  end
end
