class SourceData
# @@TIME_FORMAT = '%Y-%m-%dT%H:%M:%S'

  def self.get_source_data(metric, check_start, period)
    method_name = 'get_source_data_from_' + metric.source
    SourceData.send(method_name, metric, check_start, period)
  end

  def self.get_source_data_from_librato(metric, check_start, period)
    start_time, end_time = get_time_range(check_start, period)
    intervals = divide_time_range_for_librato(start_time, end_time, period)
    source_data = []
    intervals.each do |interval_start, interval_end|
      url = 'https://metrics-api.librato.com/v1/'
      url += "metrics/#{metric['metric']}"
      url += "?start_time=#{interval_start.to_i}"
      url += "&end_time=#{interval_end.to_i}"
      url += "&resolution=#{1.send(period)}"
      basic_auth = {:username => metric['username'], :password => metric['password']}
      response = HTTParty.get(url, :basic_auth => basic_auth)
      interval_data = response['measurements']['unassigned'].map do |element|
        time = Time.strptime(element['measure_time'].to_s, '%s')
        value = element['value']
        {'x' => time.strftime(@@TIME_FORMAT), 'y' => value}
      end
      source_data.concat(interval_data)
    end
    source_data
  end

  def self.get_date_range(metric, check_start, period)
    if period == 'hour'
      start_time = check_start - 30.days
    elsif period == 'day'
      start_time = check_start - 26.weeks
    elsif period == 'week'
      start_time = check_start - 12.months
    elsif period == 'month'
      start_time = check_start - 5.years
    end
    if start_time < metric.data_start
      start_time = advance_time(metric.data_start, period)
    end
    end_time = check_start + 1.send(period)
    [start_time, end_time]
  end

  def self.advance_time(time, advance_until)
    """
    Snaps the time to the next period start
    For example: advance '2013-01-05T12:50:35Z0000'
    until 'day' start would become '2013-02-00T00:00:00Z0000'
    """
    advanced_time = time
    if advance_until == 'hour'
      if time.minute > 0 || time.second > 0
        advanced_time = Time.new(
          time.year, time.month, time.day,
          time.hour + 1, 0, 0, 0
        ).utc
      end
    elsif ['day', 'week'].include?(advance_until)
      if time.hour > 0 || time.minute > 0 || time.second > 0
        advanced_time = Time.new(
          time.year, time.month, time.day + 1,
          0, 0, 0, 0
        ).utc
      end
      if advance_until == 'week'
        advanced_time += ((8 - advanced_time.wday) % 7).days
      end
    elsif advance_until == 'month'
      if time.day > 1 || time.hour > 0 || time.minute > 0 || time.second > 0
        advanced_time = Time.new(
          time.year, time.month + 1, 0,
          0, 0, 0, 0
        ).utc
      end
    end
  end

  def divide_interval_for_librato(start_time, end_time, period)
    """
    librato only permits queries that return 100 elements at most
    if period is hours (for example)
    it will permit a 100 hours interval (4 days and 4 hours)
    hence, longer queries must be split
    """
    intervals = []
    interval_start = start_time
    while interval_start < end_time
      interval_end = interval_start + 100.send(period)
      interval_end = end_time if interval_end > end_time
      intervals.push([interval_start, interval_end])
      interval_start = interval_end
    end
    intervals
  end
end

# @@TIME_FORMAT = '%Y-%m-%dT%H:%M:%S'

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

#   private



#   def get_sliced_data(control_data, control_period, granularity)
#     if granularity == 'hour'
#       if control_period == 'hour'
#         control_data[-[24, control_data.size].min..-1]
#       elsif control_period == 'day'
#         slices = control_data.each_slice(24)
#         slices.map{|slice| slice[0]}[-[30, slices.size].min..-1]
#       elsif control_period == 'week'
#         slices = control_data.each_slice(168)
#         slices.map{|slice| slice[0]}[-[26, slices.size].min..-1]
#       end
#     elsif granularity == 'day'
#       if control_period == 'day'
#         control_data[-[30, control_data.size].min..-1]
#       elsif control_period == 'week'
#         slices = control_data.each_slice(7)
#         slices.map{|slice| slice[0]}[-[26, slices.size].min..-1]
#       elsif control_period == 'month'
#         initial_day = Time.strptime(control_data[0]['x'], @@TIME_FORMAT)
#         last_day = Time.strptime(control_data[-1]['x'], @@TIME_FORMAT)
#         current_day = initial_day
#         sum_counter = 0
#         sliced_data = []
#         while current_day < last_day
#           current_element = control_data.select do |element|
#             Time.strptime(element['x'], @@TIME_FORMAT) == current_day
#           end
#           sliced_data.push(current_element[0])
#           sum_counter += 1
#           current_day = initial_day + sum_counter.months
#         end
#         sliced_data[-[12, sliced_data.size].min..-1]
#       end
#     elsif granularity == 'week'
#       if control_period == 'week'
#         control_data[-[26, control_data.size].min..-1]
#       elsif control_period == 'month'
#         nil #TODO! pick the most centered week
#       end
#     elsif granularity == 'months'
#       control_data[-[12, control_data.size].min..-1]
#     end
