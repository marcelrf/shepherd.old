class SourceData
  @@TIME_FORMAT = '%Y-%m-%dT%H:%M:%SZ%z'

  def self.get_source_data(metric, check_start, period)
    method_name = 'get_source_data_from_' + metric.source_info['source']
    SourceData.send(method_name, metric, check_start, period)
  end

  def self.get_source_data_from_librato(metric, check_start, period)
    start_time, end_time = get_time_range(metric, check_start, period)
    # adapt time range representation to librato format
    # who considers both start date and end date as inclusive
    start_time += 1.hour
    # librato only accepts periods up to 1 hour
    # and queries up to 100 elements
    intervals = divide_time_range(start_time, end_time, 'hour', 100)
    source_info = metric.source_info
    source_data = Hash.new{|hash, key| hash[key] = 0}
    intervals.each do |interval_start, interval_end|
      url = 'https://metrics-api.librato.com/v1/'
      url += "metrics/#{source_info['metric']}"
      url += "?start_time=#{interval_start.to_i}"
      url += "&end_time=#{interval_end.to_i}"
      url += "&resolution=3600"
      basic_auth = {:username => source_info['username'], :password => source_info['password']}
      response = HTTParty.get(url, :basic_auth => basic_auth)
      response['measurements'].keys.each do |data_group|
        response['measurements'][data_group].each do |element|
          time = Time.strptime(element['measure_time'].to_s, '%s').utc
          source_data[time] += element['sum']
        end
      end
    end
    group_data_by_period(source_data.to_a, period).map{|element| element[1]}
  end

  def self.get_time_range(metric, check_start, period)
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
      if time.min > 0 || time.sec > 0
        advanced_time = Time.new(
          time.year, time.month, time.day,
          time.hour, 0, 0, 0
        ).utc + 1.hour
      end
    elsif ['day', 'week'].include?(advance_until)
      if time.hour > 0 || time.min > 0 || time.sec > 0
        advanced_time = Time.new(
          time.year, time.month, time.day,
          0, 0, 0, 0
        ).utc + 1.day
      end
      if advance_until == 'week'
        advanced_time += ((8 - advanced_time.wday) % 7).days
      end
    elsif advance_until == 'month'
      if time.day > 1 || time.hour > 0 || time.min > 0 || time.sec > 0
        advanced_time = Time.new(
          time.year, time.month, 1,
          0, 0, 0, 0
        ).utc + 1.month
      end
    end
    advanced_time
  end

  def self.divide_time_range(start_time, end_time, period, max_elements)
    """
    Divides a time range in smaller time ranges
    For services that do not support queries
    longer than max_elements max_elements
    """
    intervals = []
    interval_start = start_time
    while interval_start < end_time
      interval_end = interval_start + max_elements.send(period)
      interval_end = end_time if interval_end > end_time
      intervals.push([interval_start, interval_end])
      interval_start = interval_end
    end
    intervals
  end

  def self.group_data_by_period(data, period)
    grouped_data = Hash.new{|hash, key| hash[key] = 0}
    data.each do |element|
      time, value = element
      advanced_time = advance_time(time, period)
      grouped_data[advanced_time] += value
    end
    grouped_data.to_a.sort_by{|element| element[0]}
  end
end
