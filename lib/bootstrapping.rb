class Bootstrapping
  def self.get_bootstrapping_analysis(data, period)
    control_data, current_data = data[0...-1], data[-1]
    periods = ['hour', 'day', 'week', 'month']
    periods_to_analyze = periods[periods.index(period)..periods.index(period)+2]
    period_percentiles = {}
    periods_to_analyze.each do |period_to_analyze|
      period_data = slice_control_data(control_data, period, period_to_analyze)
      values = period_data.map{|element| element[1]}
      percentiles = get_bootstrapping_percentiles(values)
      period_percentiles[period_to_analyze] = percentiles
    end
    puts period_percentiles
  end

  def self.slice_control_data(base_data, base_period, target_period)
    puts base_data.size, base_period, target_period
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
    weighted_values = []
    counter, magic_number = 1, 1
    while magic_number <= values.count
      (1..magic_number).each do |index|
        weighted_values.push(values[-index])
      end
      counter += 1
      magic_number += counter
    end
    weighted_values.concat(values)
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
end


#   def analyze_metric
#     control_periods = get_control_periods(granularity, metric.seasonalities)
#     start_time, end_time = get_date_range(check_start, check_end, control_periods[-1])
#     source_data = get_source_data(source_info, start_time, end_time, granularity)
#     'control_data', current_data = source_data[0...-1], source_data[-1]

#     bootstrapping_results = {}
#     control_periods.each do |control_period|
#       period_data = get_sliced_data(control_data, control_period, granularity)
#       period_values = period_data.map{|element| element['y']}
#       period_percentiles = get_bootstrapping_percentiles(period_values)
#       bootstrapping_results[control_period] = period_percentiles
#     end

#     accumulated_low, accumulated_median, accumulated_high = 0, 0, 0
#     bootstrapping_results.each do |period, percentiles|
#       accumulated_low += percentiles['low']
#       accumulated_median += percentiles['median']
#       accumulated_high += percentiles['high']
#     end
#     total_low = accumulated_low / bootstrapping_results.count
#     total_median = accumulated_median / bootstrapping_results.count
#     total_high = accumulated_high / bootstrapping_results.count

#     difference = current_data['y'] - total_median
#     if difference > 0
#       divergence = difference / (total_high - total_median)
#     elsif difference < 0 
#       divergence = -difference / (total_low - total_median)
#     else
#       divergence = 0
#     end

#     render :json => {
#       'low' => total_low,
#       'median' => total_median,
#       'high' => total_high,
#       'value' => current_data['y'],
#       'divergence' => divergence,
#       'data' => source_data[-[30, source_data.size].min..-1],
#     }
#   end
