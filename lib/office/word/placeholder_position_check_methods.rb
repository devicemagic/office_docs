module Word
  module PlaceholderPositionCheckMethods
    def placeholders_are_in_different_table_cells_in_same_row?(start_placeholder, end_placeholder)
      start_placeholder_parent = start_placeholder[:paragraph_object].node.parent
      end_placeholder_parent = end_placeholder[:paragraph_object].node.parent

      start_placeholder_parent.name == 'tc' &&
      end_placeholder_parent.name == 'tc' &&
      start_placeholder_parent != end_placeholder_parent &&
      start_placeholder_parent.parent == end_placeholder_parent.parent
    end

    def start_placeholders_is_in_table_cell_but_end_is_not_in_row?(start_placeholder, end_placeholder)
      start_placeholder_parent = start_placeholder[:paragraph_object].node.parent
      end_placeholder_parent = end_placeholder[:paragraph_object].node.parent

      return false if start_placeholder_parent.name != 'tc'

      # First one is in a table cell - just need to make sure end is a tc and in the same row
      end_placeholder_parent.name != 'tc' ||
      start_placeholder_parent.parent != end_placeholder_parent.parent
    end

    def placeholders_are_in_different_containers?(start_placeholder, end_placeholder)
      start_placeholder_parent = start_placeholder[:paragraph_object].node.parent
      end_placeholder_parent = end_placeholder[:paragraph_object].node.parent

      start_placeholder_parent != end_placeholder_parent
    end

    def resync_paragraph(container, paragraph_index, paragraph, remove_paragraph = false)
      container.parse_paragraph_at_index(container.container_node, paragraph_index, paragraph, remove_paragraph)
      paragraphs = container.paragraphs
    end

    def resync_paragraphs(container, paragraphs, remove_paragraphs = [])
      container.parse_paragraphs_at_index(container.container_node, paragraphs, remove_paragraphs)
      paragraphs = container.paragraphs
    end

    def resync_container(container)
      container.parse_paragraphs(container.container_node)
      paragraphs = container.paragraphs
    end
  end
end
