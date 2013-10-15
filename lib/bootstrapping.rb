class Bootstrapping
  def self.get_bootstrapping_analysis(data, period)
    periods = ['hour', 'day', 'week', 'month']
    periods_to_analyze = periods[periods.index(period)..-1]
    period_percentiles = {}
    periods_to_analyze.each do |period_to_analyze|
      period_data = get_period_data(data, period, period_to_analyze)
      # percentiles = get_bootstrapping_percentiles(period_data)
      # period_percentiles[period_to_analyze] = percentiles
    end
    # puts period_percentiles
  end

  def self.get_period_data(base_data, base_period, target_period)
    if base_period == 'hour'
      if target_period == 'hour'
        base_data[-[24, base_data.size].min..-1]
      elsif target_period == 'day'
        slices = base_data.each_slice(24)
        slices.map{|slice| slice[0]}[-[30, slices.size].min..-1]
      elsif target_period == 'week'
        slices = base_data.each_slice(168)
        slices.map{|slice| slice[0]}[-[26, slices.size].min..-1]
      end
    elsif base_period == 'day'
      if target_period == 'day'
        base_data[-[30, base_data.size].min..-1]
      elsif target_period == 'week'
        slices = base_data.each_slice(7)
        slices.map{|slice| slice[0]}[-[26, slices.size].min..-1]
      elsif target_period == 'month'
        initial_day = Time.strptime(base_data[0]['x'], @@TIME_FORMAT)
        last_day = Time.strptime(base_data[-1]['x'], @@TIME_FORMAT)
        current_day = initial_day
        sum_counter = 0
        sliced_data = []
        while current_day < last_day
          current_element = base_data.select do |element|
            Time.strptime(element['x'], @@TIME_FORMAT) == current_day
          end
          sliced_data.push(current_element[0])
          sum_counter += 1
          current_day = initial_day + sum_counter.months
        end
        sliced_data[-[12, sliced_data.size].min..-1]
      end
    elsif base_period == 'week'
      if target_period == 'week'
        base_data[-[26, base_data.size].min..-1]
      elsif target_period == 'month'
        nil #TODO! pick the most centered week
      end
    elsif base_period == 'month'
      base_data[-[12, base_data.size].min..-1]
    end
  end

end

# @@TIME_FORMAT = '%Y-%m-%dT%H:%M:%S'

# def get_bootstrapping_percentiles(values)
  #   samples = get_bootstrapping_samples(values, 1000)
  #   # transform samples into percentiles
  #   percentiles = samples.map do |sample|
  #     freqs = Hash.new{|h, k| h[k] = 0}
  #     sample.each do |value|
  #       freqs[value] += 1
  #     end
  #     relative_freqs = freqs.keys.sort.map do |value|
  #       [value, freqs[value].to_f / sample.size]
  #     end
  #     accum_freq = 0
  #     percentile05 = percentile50 = percentile95 = 0
  #     relative_freqs.each do |value, rel_freq|
  #       new_accum_freq = accum_freq + rel_freq
  #       if accum_freq < 0.05 && new_accum_freq >= 0.05
  #         percentile05 = value
  #       elsif accum_freq < 0.5 && new_accum_freq >= 0.5
  #         percentile50 = value
  #       elsif accum_freq < 0.95 && new_accum_freq >= 0.95
  #         percentile95 = value
  #       end
  #       accum_freq = new_accum_freq
  #     end
  #     [percentile05, percentile50, percentile95]
  #   end
  #   # get percentile means
  #   percentile05_accum = percentile50_accum = percentile95_accum = 0
  #   percentiles.each do |percentile|
  #     percentile05_accum += percentile[0]
  #     percentile50_accum += percentile[1]
  #     percentile95_accum += percentile[2]
  #   end
  #   percentile05_mean = percentile05_accum.to_f / percentiles.size
  #   percentile50_mean = percentile50_accum.to_f / percentiles.size
  #   percentile95_mean = percentile95_accum.to_f / percentiles.size
  #   {
  #     'low' => percentile05_mean,
  #     'median' => percentile50_mean,
  #     'high' => percentile95_mean,
  #   }
  # end

  # def get_bootstrapping_samples(values, iterations)
  #   # give weight to values depending on how recent they are
  #   # using a magic number algorithm
  #   weighted_values = []
  #   counter, magic_number = 1, 1
  #   while magic_number <= values.count
  #     (1..magic_number).each do |index|
  #       weighted_values.push(values[-index])
  #     end
  #     counter += 1
  #     magic_number += counter
  #   end
  #   weighted_values.concat(values)
  #   # create the samples
  #   samples = []
  #   iterations.times do
  #     sample = []
  #     values.size.times do
  #       sample.push(weighted_values[(rand * weighted_values.size).to_i])
  #     end
  #     samples.push(sample)
  #   end
  #   samples
  # end

#   def analyze_metric
#     control_periods = get_control_periods(granularity, metric.seasonalities)
#     start_time, end_time = get_date_range(check_start, check_end, control_periods[-1])
#     source_data = get_source_data(source_info, start_time, end_time, granularity)
#     control_data, current_data = source_data[0...-1], source_data[-1]

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
