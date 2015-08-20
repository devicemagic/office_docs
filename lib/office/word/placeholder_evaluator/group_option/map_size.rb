class PlaceholderEvaluator::GroupOption::MapSize
  def apply_option
    width, height = get_width_and_height_from_params
    placeholder.group_generation_options[:map_size][:width] = width
    placeholder.group_generation_options[:map_size][:height] = height
  end
end
