class SourceData
  @@TIME_FORMAT = '%Y-%m-%dT%H:%M:%SZ%z'

  def self.get_source_data(metric, check_start, period)
    source_info = metric.get_source_info
    method_name = 'get_source_data_from_' + source_info['name']
    SourceData.send(method_name, metric, check_start, period)
  end

  def self.get_source_data_from_librato(metric, check_start, period)
    Rails.logger.info "GET DATA #{metric.name} #{check_start} #{period}"
    check_start -= 1.hours # TODO: REMOVE THIS LINE (provisory bug patch) !!!!!!!!!!!!!!!!!!!!!
    start_time, end_time = get_time_range(check_start, period)
    # adapt time range representation to librato format
    # who considers both start date and end date as inclusive
    start_time += 1.hour
    cache_data, start_time = get_cache_data(metric, start_time, end_time, period)
    # initialize source data
    source_data = {}
    index_time = start_time
    while index_time <= end_time
      source_data[index_time] = 0
      index_time += 1.hour
    end
    source_info = metric.get_source_info
    # librato only accepts periods up to 1 hour
    # and queries up to 100 elements
    intervals = divide_time_range(start_time, end_time, 'hour', 100)
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
    grouped_data = group_data_by_period(source_data.to_a, period)
    full_source_data = cache_data + grouped_data
    set_cache_data(metric, period, full_source_data)
    Rails.logger.info "END GET DATA #{metric.name} #{check_start} #{period}"
    full_source_data
  end

  def self.get_cache_data(metric, start_time, end_time, period)
    no_cache_data = [[], start_time]
    return no_cache_data # TODO: correct and enable cache !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    cache_key = JSON.dump({
      'metric' => metric.id,
      'period' => period
    })
    cache_data_json = $redis.hget('source_data', cache_key)
    if cache_data_json
      cache_data = JSON.load(cache_data_json).map do |element|
        [Time.parse(element[0], @@TIME_FORMAT).utc, element[1]]
      end
      if cache_data[0][0] <= start_time
        cache_data.shift while cache_data[0][0] < start_time
        cache_data.pop while cache_data[-1][0] > end_time
        [cache_data, cache_data[-1][0] + 1.send(period)]
      else
        no_cache_data
      end
    else
      no_cache_data
    end
  end

  def self.set_cache_data(metric, period, data)
    cache_key = JSON.dump({
      'metric' => metric.id,
      'period' => period
    })
    formatted_data = data.map do |element|
      [element[0].strftime(@@TIME_FORMAT), element[1]]
    end
    data_json = JSON.dump(formatted_data)
    $redis.hset('source_data', cache_key, data_json)
  end

  def self.get_time_range(check_start, period)
    if period == 'hour'
      start_time = check_start - 30.days
    elsif period == 'day'
      start_time = check_start - 26.weeks
    elsif period == 'week'
      start_time = check_start - 24.months
    elsif period == 'month'
      start_time = check_start - 24.months
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

  def self.get_metrics_from_librato(username, password, pattern)
    url = 'https://metrics-api.librato.com/v1/'
    url += "metrics?name=#{pattern}"
    basic_auth = {:username => username, :password => password}
    HTTParty.get(url, :basic_auth => basic_auth)['metrics']
  end
end
