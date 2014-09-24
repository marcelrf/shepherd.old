module MapsHelper
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

  def cell_color(metric, divergence)
    if !metric
      "#FFFFFF"
    elsif !divergence
      "#F0F0F0"
    elsif divergence <= 1 && divergence >= -1
      "#FFFFFF"
    elsif divergence > 1
      red_blue = (255 - (-1 / (((divergence - 1) / 2) + 1) + 1) * 255).to_i.to_s(16)
      red_blue = "0#{red_blue}" if red_blue.size == 1
      "##{red_blue}FF#{red_blue}"
    else
      green_blue = (255 - (-1 / (((-divergence - 1) / 2) + 1) + 1) * 255).to_i.to_s(16)
      green_blue = "0#{green_blue}" if green_blue.size == 1
      "#FF#{green_blue}#{green_blue}"
    end
  end

  def format_divergence(metric, divergence)
    if !metric
      nil
    elsif divergence
      if divergence >= 0
        "+#{divergence.round(2)}"
      else
        "#{divergence.round(2)}"
      end
    else
      ''
    end
  end

  def chart_url(metric, time)
    url = "https://metrics.librato.com/metrics/#{metric.name}?duration=864000"
    url += "&end_time=#{time.to_i}" if time
    url
  end
end
