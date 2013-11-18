class Bootstrapping
  def self.get_bootstrapping_analysis(data, period)
    control_data, current_data = data[0...-1], data[-1]
    return nil if control_data.size < minimum_size(period)
    control_gap = control_data.map{|e| e[1]}.max - control_data.map{|e| e[1]}.min
    periods = ['hour', 'day', 'week', 'month']
    periods_to_analyze = periods[periods.index(period)..periods.index(period)+2]
    percentiles = Hash.new{|h, k| h[k] = 0}
    divider = 0
    periods_to_analyze.each do |period_to_analyze|
      period_data = slice_control_data(control_data, period, period_to_analyze)
      period_percentiles = get_bootstrapping_percentiles(period_data)
      period_factor = get_period_factor(period_to_analyze, period_data, period_percentiles, control_gap)
      period_percentiles.keys.each do |percentile|
        percentiles[percentile] += period_percentiles[percentile] * period_factor
      end
      divider += period_factor
    end
    percentiles.keys.each do |percentile|
      percentiles[percentile] /= divider
    end
    difference = current_data[1] - percentiles['median']
    if difference > 0
      divergence = difference / (percentiles['high'] - percentiles['median'])
    elsif difference < 0 
      divergence = -difference / (percentiles['low'] - percentiles['median'])
    else
      divergence = 0
    end
    percentiles['value'] = current_data[1]
    percentiles['divergence'] = divergence
    percentiles
  end

  def self.slice_control_data(base_data, base_period, target_period)
    if base_period == 'hour'
      if target_period == 'hour'
        base_data.reverse[0...24].reverse
      elsif target_period == 'day'
        slices = base_data.reverse.each_slice(24)
        slices = slices.select{|slice| slice.size == 24}
        slices.map{|slice| slice[-1]}[0...30].reverse
      elsif target_period == 'week'
        slices = base_data.reverse.each_slice(168)
        slices = slices.select{|slice| slice.size == 168}
        slices.map{|slice| slice[-1]}[0...26].reverse
      end
    elsif base_period == 'day'
      if target_period == 'day'
        base_data.reverse[0...30].reverse
      elsif target_period == 'week'
        slices = base_data.reverse.each_slice(7)
        slices = slices.select{|slice| slice.size == 7}
        slices.map{|slice| slice[-1]}[0...26].reverse
      elsif target_period == 'month'
        current_day = base_data[-1][0] + 1.day
        months_ago = 1
        target_month = current_day - months_ago.months
        sliced_data = []
        base_data.reverse.each do |element|
          if element[0] == target_month
            sliced_data.push(element)
            months_ago += 1
            target_month = current_day - months_ago.months
          end
        end
        sliced_data.reverse
      end
    elsif base_period == 'week'
      if target_period == 'week'
        base_data.reverse[0...26].reverse
      elsif target_period == 'month'
        current_week = base_data[-1][0] + 1.week
        months_ago = 1
        target_month = current_week - months_ago.months
        sliced_data = []
        base_data.reverse.each do |element|
          if (element[0] >= target_month - 3.days &&
              element[0] <= target_month + 3.days)
            sliced_data.push(element)
            months_ago += 1
            target_month = current_week - months_ago.months
          end
        end
        sliced_data.reverse
      end
    elsif base_period == 'month'
      base_data.reverse[0...24].reverse
    end
  end

  def self.get_bootstrapping_percentiles(values)
    samples = get_bootstrapping_samples(values, 1000)
    # transform samples into percentiles
    percentiles = samples.map do |sample|
      freqs = Hash.new{|h, k| h[k] = 0}
      sample.each do |value|
        freqs[value] += 1
      end
      relative_freqs = freqs.keys.sort.map do |value|
        [value, freqs[value].to_f / sample.size]
      end
      accum_freq = 0
      percentile05 = percentile50 = percentile95 = 0
      relative_freqs.each do |value, rel_freq|
        new_accum_freq = accum_freq + rel_freq
        if accum_freq < 0.05 && new_accum_freq >= 0.05
          percentile05 = value
        elsif accum_freq < 0.5 && new_accum_freq >= 0.5
          percentile50 = value
        elsif accum_freq < 0.95 && new_accum_freq >= 0.95
          percentile95 = value
        end
        accum_freq = new_accum_freq
      end
      [percentile05, percentile50, percentile95]
    end
    # get percentile means
    percentile05_accum = percentile50_accum = percentile95_accum = 0
    percentiles.each do |percentile|
      percentile05_accum += percentile[0]
      percentile50_accum += percentile[1]
      percentile95_accum += percentile[2]
    end
    percentile05_mean = percentile05_accum.to_f / percentiles.size
    percentile50_mean = percentile50_accum.to_f / percentiles.size
    percentile95_mean = percentile95_accum.to_f / percentiles.size
    {
      'low' => percentile05_mean,
      'median' => percentile50_mean,
      'high' => percentile95_mean,
    }
  end

  def self.get_bootstrapping_samples(values, iterations)
    # give weight to values depending on how recent they are
    # using a magic number algorithm
    magic_number = 0.95 #0.994
    last_value_timestamp = values[-1][0].to_i
    weighted_values = []
    values.each do |element|
      value_timestamp = element[0].to_i
      time_proportion = value_timestamp / last_value_timestamp.to_f
      time_factor = 1 / (1 + Math.log(time_proportion) / Math.log(magic_number))
      (time_factor * 10).ceil.times do
        weighted_values.push(element[1])
      end
    end
    # create the samples
    samples = []
    iterations.times do
      sample = []
      values.size.times do
        sample.push(weighted_values[(rand * weighted_values.size).to_i])
      end
      samples.push(sample)
    end
    samples
  end

  def self.get_period_factor(period, data, percentiles, gap)
    if period == 'hour'
      confidence = get_confidence(data.count, 24)
    elsif period == 'day'
      confidence = get_confidence(data.count, 30)
    elsif period == 'week'
      confidence = get_confidence(data.count, 26)
    elsif period == 'month'
      confidence = get_confidence(data.count, 24)
    end
    compactness = 1 - (percentiles['high'] - percentiles['low']) / gap
    (confidence * compactness) ** 3
  end

  def self.get_confidence(count, max)
    count / max.to_f
  end

  def self.minimum_size(period)
    if period == 'hour'
      168
    elsif period == 'day'
      30
    elsif period == 'week'
      10
    elsif period == 'month'
      6
    end
  end
end
