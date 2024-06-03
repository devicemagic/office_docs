require 'office/word/if_else_replacers/base'

module Word
  module IfElseReplacers
    class IfElseInParagraph < Word::IfElseReplacers::Base

      def replace_if_else(start_placeholder, end_placeholder, inbetween_placeholders, all_placeholders)
        paragraph = start_placeholder[:paragraph_object]

        end_run = replace_placeholder_with_blank_runs(end_placeholder)
        start_run = replace_placeholder_with_blank_runs(start_placeholder)

        from_run = paragraph.runs.index(start_run) + 1
        to_run = paragraph.runs.index(end_run) - 1

        inbetween_runs = paragraph.runs[from_run..to_run]
        should_keep = evaluate_if(start_placeholder[:placeholder_text])

        new_placeholders = []

        # remove all placeholders for the paragraph, since start and end are the same paragraph use the start index 
        all_placeholders.reject! { |placeholder| placeholder[:paragraph_index] == start_placeholder[:paragraph_index]}

        if !should_keep
          inbetween_runs.each do |run|
            paragraph.remove_run(run)
          end

          if paragraph.is_blank?
            Word::Template.remove_node(paragraph.node)
          end

          if !paragraph.is_blank?
             #reget all the placeholders for the paragraph if the paragraph is not blank
            new_placeholders = Word::PlaceholderFinder.get_placeholders_from_paragraph(paragraph, start_placeholder[:paragraph_index])
          end

          # add the new placeholders to the all_placeholders array
          all_placeholders.concat(new_placeholders)

          # sort the all_placeholders array by paragraph index and run index as secondary
          sort_placeholders(all_placeholders)

         return { paragraph: paragraph, remove: paragraph.is_blank?, placeholders: all_placeholders }  
        end

        # reget all the placeholders for the paragraph
        new_placeholders = Word::PlaceholderFinder.get_placeholders_from_paragraph(paragraph, start_placeholder[:paragraph_index])

        # add the new placeholders to the all_placeholders array
        all_placeholders.concat(new_placeholders)

        # sort the all_placeholders array by paragraph index
        sort_placeholders(all_placeholders)

        return  { paragraph: paragraph, remove: false, placeholders: all_placeholders }  
      end

      def sort_placeholders(placeholders)
        placeholders.sort! do |a, b|
          # Compare paragraph_index
          compare_paragraph = a[:paragraph_index] <=> b[:paragraph_index]
          return compare_paragraph unless compare_paragraph.zero?
        
          # If paragraph_index is equal, compare run_index within beginning_of_placeholder
          compare_run = a[:beginning_of_placeholder][:run_index] <=> b[:beginning_of_placeholder][:run_index]
          return compare_run unless compare_run.zero?
        
          # If run_index is equal, compare char_index within beginning_of_placeholder
          a[:beginning_of_placeholder][:char_index] <=> b[:beginning_of_placeholder][:char_index]
        end
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
