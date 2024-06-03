require 'office/word/if_else_replacers/base'

module Word
  module IfElseReplacers
    class IfElseOverParagraphs < Word::IfElseReplacers::Base
      attr_accessor :placeholders, :paragraphs_to_remove, :blank_runs_count, :indexes_removed

      def replace_if_else(start_placeholder, end_placeholder, inbetween_placeholders, placeholders)
        self.placeholders = placeholders
        self.paragraphs_to_remove = []
        self.indexes_removed = []

        container = start_placeholder[:paragraph_object].document
        target_nodes = get_inbetween_nodes(start_placeholder, end_placeholder)
        should_keep = evaluate_if(start_placeholder[:placeholder_text])


        placeholder_dup2 = placeholders.dup

        mapped2 = placeholder_dup2.map do |placeholder|
          placeholder.dup.tap { |new_p| new_p.delete(:paragraph_object) }
        end

        #byebug if placeholders.any? { |placeholder| placeholder[:placeholder_text].include?("Q_Q") }
        #byebug if placeholders.any? { |placeholder| placeholder[:placeholder_text].include?("{% if !fields.d %}") }
        
        if !should_keep
          target_nodes.each do |node|
            Word::Template.remove_node(node)
          end

          # # if we shouldn't keep, let's remove all placeholders between start/end 
          range_to_remove = (start_placeholder[:paragraph_index]..end_placeholder[:paragraph_index]).to_a
          self.paragraphs_to_remove += range_to_remove
   
          reindex_placeholders_new(placeholders, range_to_remove)
          sort_placeholders(placeholders)

          return { paragraphs: ['', ''], paragraphs_to_remove: self.paragraphs_to_remove, placeholders: placeholders }
        else


         

          placeholder_dup2 = placeholders.dup

          mapped2 = placeholder_dup2.map do |placeholder|
            placeholder.dup.tap { |new_p| new_p.delete(:paragraph_object) }
          end
 
          # remove the start and end for the specific paragraph index

          placeholder_len_before = placeholders.dup.length 
          new_start_placeholders = Word::PlaceholderFinder.get_placeholders_from_paragraph(start_placeholder[:paragraph_object], start_placeholder[:paragraph_index]) || []
          new_end_placeholders = Word::PlaceholderFinder.get_placeholders_from_paragraph(end_placeholder[:paragraph_object], end_placeholder[:paragraph_index]) || []


          self.paragraphs_to_remove << start_placeholder[:paragraph_index] if new_start_placeholders.length == 0
          self.paragraphs_to_remove << end_placeholder[:paragraph_index] if new_end_placeholders.length == 0


          # if we have no new placeholders, we should the existing placeholders from the placeholders hash. the paragraph object is updated in place. 


        if (new_start_placeholders.length == 0 && new_end_placeholders.length == 0) 

          placeholders.reject! { |placeholder| start_placeholder[:paragraph_index] == placeholder[:paragraph_index]} 
          placeholders.reject! { |placeholder| end_placeholder[:paragraph_index] == placeholder[:paragraph_index]}

          if (self.indexes_removed.length > 0 && is_inbetween_start_and_end?(self.indexes_removed[0], start_placeholder[:paragraph_index], end_placeholder[:paragraph_index]) && placeholders.length > 0) 
            re_index_placeholders_when_start_and_end_are_removed(placeholders, start_placeholder[:paragraph_index], true)
          else
            re_index_placeholders_when_start_and_end_are_removed(placeholders, start_placeholder[:paragraph_index], false)
          end

        
          placeholder_dup2 = placeholders.dup

          thing = placeholder_dup2.map do |placeholder|
            placeholder.dup.tap { |new_p| new_p.delete(:paragraph_object) }
          end

        else
          placeholders.concat(new_start_placeholders)
          placeholders.concat(new_end_placeholders)
        end

        sort_placeholders(placeholders)

        #byebug if placeholders.any? { |placeholder| placeholder[:placeholder_text].include?("Q_Q") }

          return { 
            paragraphs: [
              { index: start_placeholder[:paragraph_index], paragraph: start_placeholder[:paragraph_object] },
              { index: end_placeholder[:paragraph_index], paragraph: end_placeholder[:paragraph_object] },
            ], 
            paragraphs_to_remove: [], 
            placeholders: placeholders 
        }
        end 
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

      def re_index_placeholders_when_start_and_end_are_removed(placeholders, removed_start_index, blank_inbetween_paragraph_removed = false)
        placeholders.map! do |placeholder|
          if (placeholder[:paragraph_index] > removed_start_index) 
            blank_inbetween_paragraph_removed ? placeholder[:paragraph_index] -= 2 : placeholder[:paragraph_index] -= 1
          end
          placeholder
        end
      end

      def reindex_placeholders_new(placeholders, removed_paragraphs)
        # Sort the removed paragraphs in descending order to avoid index issues
        removed_paragraphs.sort! { |a, b| b <=> a }
      
        # Filter out the placeholders that are part of removed_paragraphs
        placeholders.reject! { |placeholder| removed_paragraphs.include?(placeholder[:paragraph_index]) }
      
        # Update the paragraph index based on the removed paragraphs
        placeholders.each do |placeholder|
          removed_paragraphs.each do |removed_paragraph|
            placeholder[:paragraph_index] -= 1 if removed_paragraph < placeholder[:paragraph_index]
          end
        end
      
        # Return the updated placeholder set
        placeholders
      end

      def is_inbetween_start_and_end?(index_to_check, start_index, end_index)
        return false if index_to_check == start_index || index_to_check == end_index

        index_to_check.between?(start_index, end_index) 
      end
      
      def re_index_placeholders(placeholders, start_index)
        #todo reindex after start_index
        placeholders.map do |placeholder|
          if placeholder[:paragraph_index] > start_index
            placeholder[:paragraph_index] -= 2
          end
          placeholder
        end
      end

      def get_inbetween_nodes(start_placeholder, end_placeholder)
        start_paragraph = start_placeholder[:paragraph_object]
        end_paragraph = end_placeholder[:paragraph_object]
        document = start_paragraph.document

        container = start_paragraph.node.parent
        start_node = start_paragraph.node
        end_node = end_paragraph.node

        starts_with = start_paragraph.plain_text.start_with?(start_placeholder[:placeholder_text])
        ends_with = end_paragraph.plain_text.end_with?(end_placeholder[:placeholder_text])

        start_run = start_paragraph.replace_first_with_empty_runs(start_placeholder[:placeholder_text]).last
        end_run = end_paragraph.replace_first_with_empty_runs(end_placeholder[:placeholder_text]).first

        if start_paragraph.plain_text.gsub(" ", "").length == 0
          start_placeholder_paragraph = start_paragraph
          index = container.children.index(start_node)
          start_node = container.children[index + 1]
          document.remove_paragraph(start_placeholder_paragraph)
        else
          start_paragraph = starts_with ? start_paragraph : start_paragraph.split_after_run(start_run)
          start_node = start_paragraph.node
        end

        if end_paragraph.plain_text.gsub(" ", "").length == 0
          end_placeholder_paragraph = end_paragraph

          if start_node == end_node #nothing inbetween
            document.remove_paragraph(end_placeholder_paragraph)
            return []
          else
            index = container.children.index(end_node)
            self.indexes_removed << index
            end_node = container.children[index - 1]
            document.remove_paragraph(end_placeholder_paragraph)
          end
        else
          other_dependent_placeholders = placeholders.select{|p| p[:paragraph_object] == end_paragraph && p != end_placeholder}
          new_end = end_paragraph.split_after_run(end_run) if(!ends_with)
          other_dependent_placeholders.each{|p| p[:paragraph_object] = new_end}
          end_node = end_paragraph.node
        end

        start_index = container.children.index(start_node)
        end_index = container.children.index(end_node)

        container.children[start_index..end_index]
      end

    end

  end
end
