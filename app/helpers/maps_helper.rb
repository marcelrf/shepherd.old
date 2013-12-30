module MapsHelper
  def table_measures(group_infos)
    columns = Math.sqrt(group_infos.count).ceil
    rows = columns == 0 ? 0 : (group_infos.count / columns.to_f).ceil
    table_size = 500
    cell_size = columns == 0 ? 0 : (table_size / columns.to_f).floor
    [columns, rows, table_size, cell_size]
  end

  def cell_color(metric, state)
    if !metric
      "#F0F0F0"
    elsif !state || state.divergence == 0
      "#FFFFFF"
    elsif state.divergence > 0
      red_blue = (255 - (-1 / ((state.divergence / 4) ** 2 + 1) + 1) * 255).to_i.to_s(16)
      red_blue = "0#{red_blue}" if red_blue.size == 1
      "##{red_blue}FF#{red_blue}"
    else
      green_blue = (255 - (-1 / ((-state.divergence / 4) ** 2 + 1) + 1) * 255).to_i.to_s(16)
      green_blue = "0#{green_blue}" if green_blue.size == 1
      "#FF#{green_blue}#{green_blue}"
    end
  end

  def format_divergence(metric, state)
    if !metric
      nil
    elsif state
      if state.divergence >= 0
        "+#{state.divergence}"
      else
        "-#{state.divergence}"
      end
    else
      "Still no data"
    end
  end
end
