require 'office/word/if_else_replacers/base'

module Word
  module IfElseReplacers
    class IfElseInParagraph < Word::IfElseReplacers::Base

      # Break runs on start + end
      # loop runs inbetween

      def replace_if_else(start_placeholder, end_placeholder, inbetween_placeholders, all_placeholders)
        paragraph = start_placeholder[:paragraph_object]

        end_run = replace_placeholder_with_blank_runs(end_placeholder)
        start_run = replace_placeholder_with_blank_runs(start_placeholder)

        from_run = paragraph.runs.index(start_run) + 1
        to_run = paragraph.runs.index(end_run) - 1

        inbetween_runs = paragraph.runs[from_run..to_run]
        should_keep = evaluate_if(start_placeholder[:placeholder_text])

        if !should_keep
          inbetween_runs.each do |run|
            paragraph.remove_run(run)
          end

          if paragraph.is_blank?
            Word::Template.remove_node(paragraph.node)
            # reject all placeholders with the same paragraph index as the start_placeholder
            all_placeholders.reject! { |placeholder| placeholder[:paragraph_index] == start_placeholder[:paragraph_index] || placeholder[:paragraph_index] == end_placeholder[:paragraph_index]}
          end

          # remove the start and end placeholders only 
          puts "all_placeholders length before reject start and end: #{all_placeholders.length}"
          all_placeholders.reject! { |placeholder| placeholder[:paragraph_index] == start_placeholder[:paragraph_index] && start_placeholder[:placeholder_text] ==  placeholder[:placeholder_text] && start_placeholder[:paragraph_index] && placeholder[:beginning_of_placeholder] == start_placeholder[:beginning_of_placeholder] && placeholder[:end_of_placeholder] == start_placeholder[:end_of_placeholder]}
          puts "all_placeholders length after reject start and end: #{all_placeholders.length}"
          all_placeholders.reject! { |placeholder| placeholder[:paragraph_index] == end_placeholder[:paragraph_index] && end_placeholder[:placeholder_text] ==  placeholder[:placeholder_text]  && end_placeholder[:paragraph_index] && placeholder[:beginning_of_placeholder] == end_placeholder[:beginning_of_placeholder] && placeholder[:end_of_placeholder] == end_placeholder[:end_of_placeholder]}
          puts "all_placeholders length after reject start and end: #{all_placeholders.length}"
       
          #reget all the placeholders for the paragraph
          #new_placeholders = Word::PlaceholderFinder.get_placeholders_from_paragraph(paragraph, start_placeholder[:paragraph_index])
          #all_placeholders.concat(new_placeholders)
          puts "all_placeholders length after concat new_placeholders: #{all_placeholders.length}"
          all_placeholders.sort_by! { |placeholder| placeholder[:paragraph_index] }
         return { paragraph: paragraph, remove: false, placeholders: all_placeholders }  
        end

        all_placeholders.reject! { |placeholder| placeholder[:paragraph_index] == end_placeholder[:paragraph_index]}
        all_placeholders.reject! { |placeholder| placeholder[:paragraph_index] == start_placeholder[:paragraph_index]}

        # reget all the placeholders for the paragraph
        new_placeholders = Word::PlaceholderFinder.get_placeholders_from_paragraph(paragraph, start_placeholder[:paragraph_index])

        # add the new placeholders to the all_placeholders array
        all_placeholders.concat(new_placeholders)

        # sort the all_placeholders array by paragraph index
        all_placeholders.sort_by! { |placeholder| placeholder[:paragraph_index] }

        return  { paragraph: paragraph, remove: false, placeholders: all_placeholders }  
      end

      def replace_placeholder_with_blank_runs(placeholder)
        paragraph = placeholder[:paragraph_object]
        start_run_index = placeholder[:beginning_of_placeholder][:run_index]
        start_char_index = placeholder[:beginning_of_placeholder][:char_index]
        start_index = paragraph.get_index_of_text_in_paragraph(start_run_index, start_char_index)

        paragraph.replace_with_empty_run(start_index, placeholder[:placeholder_text].length)
      end
    end
  end
end
