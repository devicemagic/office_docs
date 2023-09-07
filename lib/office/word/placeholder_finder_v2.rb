module Word
    class PlaceholderFinderV2
      class << self
        #
        #
        # =>
        # => Getting placeholders
        # =>
        #
        #

      ## test submission total_time -> 0.000677
        def get_placeholders(paragraphs)
          now = Time.now
          placeholders = []
          paragraphs.each_with_index do |p, i|
            placeholders += get_placeholders_from_paragraph(p, i)
          end
          end_time = Time.now
          total_time = end_time - now
          byebug
          placeholders
        end

           # 
          #   \{\{[^}]*\}\}   # Matches placeholders enclosed in double curly braces, e.g., {{ ... }}
          #   |
          #   \{%[^%]*%\}     # Matches placeholders enclosed in curly braces with percent signs, e.g., {% ... %}
          #   |
          #   \{\{[^%]*%\}\}  # Matches placeholders enclosed in double curly braces with percent signs, e.g., {{% ... %}}
          #   |
          #   \{%[^}]*\}\}    # Matches placeholders enclosed in curly braces with percent signs, e.g., {%{ ... }}
          # 
  
        def get_placeholders_from_paragraph(paragraph, paragraph_index)
          runs = paragraph.runs
          allMatches = []
          run_texts = runs.map(&:text)
          matches = run_texts&.join&.scan(/(\{\{[^}]*\}\}|\{%[^%]*%\}|\{\{[^%]*%\}|\{%[^}]*\}\})/) || []

          if !matches.empty?
            allMatches += matches.flatten
          end
          
          allMatches
        end
      end
    end
end
  