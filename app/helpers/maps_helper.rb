module MapsHelper
  def total_width
    700
  end
  
  def total_height
    500
  end

  def table_measures(width, height, count)
    columns, rows = 1, 1
    column_width, row_height = width, height
    while count > columns * rows
      if column_width > row_height
        column_width = column_width * columns / (columns + 1)
        columns += 1
      else
        row_height = row_height * rows / (rows + 1)
        rows += 1
      end
    end
    [columns, rows, column_width, row_height]
  end

  def cell_color(metric, state)
    if !metric
      "#F0F0F0"
    elsif !state
      "#CCCCFF"
    elsif state.divergence <= 1 && state.divergence >= -1
      "#FFFFFF"
    elsif state.divergence > 1
      red_blue = (255 - (-1 / (((state.divergence - 1) / 3) ** 2 + 1) + 1) * 255).to_i.to_s(16)
      red_blue = "0#{red_blue}" if red_blue.size == 1
      "##{red_blue}FF#{red_blue}"
    else
      green_blue = (255 - (-1 / (((-state.divergence - 1) / 3) ** 2 + 1) + 1) * 255).to_i.to_s(16)
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
        "#{state.divergence}"
      end
    else
      "Still no data"
    end
  end

  def chart_url(metric)
      "https://metrics.librato.com/metrics/#{metric.name}?duration=1500000"
  end
end
