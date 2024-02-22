require 'office/word/if_else_replacers/base'

module Word
  module IfElseReplacers
    class IfElseInParagraph < Word::IfElseReplacers::Base

      # Break runs on start + end
      # loop runs inbetween

      def replace_if_else(start_placeholder, end_placeholder, inbetween_placeholders, placeholders)
        paragraph = start_placeholder[:paragraph_object]

        end_run = replace_placeholder_with_blank_runs(end_placeholder)
        start_run = replace_placeholder_with_blank_runs(start_placeholder)

        from_run = paragraph.runs.index(start_run) + 1
        to_run = paragraph.runs.index(end_run) - 1

        inbetween_runs = paragraph.runs[from_run..to_run]

        # should we keep the paragraph? does the if statement evaluate to true? if not, remove all the runs inbetween the start and end runs
        should_keep = evaluate_if(start_placeholder[:placeholder_text])

        # should we keep trsck of the runs removed from the paraaph? 
        # then we sync this specific paragraph with the document, basically replace it 
        # instead of resyncing the whole document? 


        # if we shouldn't keep, remove all the associated placeholders for the paragraph index? 
        if !should_keep
          inbetween_runs.each do |run|
            paragraph.remove_run(run)
          end

          # checks to see if the paragraph is empty and removes it if it is, nodes, sym nodes etc 
          if paragraph.is_blank?
            Word::Template.remove_node(paragraph.node)
          end

            # we have a paragraph index, we need to remove all placeholders with this paragraph index? 
          placeholders.map do |placeholder|
            if placeholder[:paragraph_index] == start_placeholder[:paragraph_index]
              nil
            end
          end 
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
