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
