class SourceData
  @@URL_ROOT = 'https://metrics-api.librato.com/v1'
  @@DATA_TEMPLATE = "/metrics/%s?start_time=%s&end_time=%s&resolution=3600"
  @@METRICS_TEMPLATE = "/metrics?name=%s&offset=%s&length=%s"
  @@TIME_FORMAT = '%Y-%m-%dT%H:%M:%SZ%z'

  def self.get_source_data(metric, period, start_time, end_time)
    source_data = []
    intervals = divide_time_range(start_time, end_time, 'hour', 100)
    intervals.reverse.each do |interval_start, interval_end|
      interval_data = get_interval_data(metric, interval_start, interval_end)
      source_data = interval_data + source_data
    end
    group_data_by_period(source_data, period)
  end

  def self.divide_time_range(start_time, end_time, period, max_elements)
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

  def self.get_interval_data(metric, start_time, end_time)
    url = @@URL_ROOT + (@@DATA_TEMPLATE % [
      metric.name,
      start_time.to_i,
      (end_time - 1.second).to_i
    ])
    basic_auth = {
      :username => metric.source.username,
      :password => metric.source.password
    }
    response = HTTParty.get(url, :basic_auth => basic_auth)
    # response = http_get(url, metric.source.username, metric.source.password)
    measurements = response && response['measurements']
    data_by_measure_time = {}
    if measurements && measurements.first
      measurements.first[1].each do |measurement|
        if metric.kind == 'counter'
          value = measurement['sum']
        elsif metric.kind == 'gauge'
          value = measurement['value']
        end
        measure_time = Time.at(measurement['measure_time'])
        data_by_measure_time[measure_time] = value
      end
    end
    data = []
    time_index = start_time
    while time_index < end_time
      value = data_by_measure_time[time_index]
      data.push(value ? value : 0)
      time_index += 1.hour
    end
    return data
  end

  def self.group_data_by_period(data, period)
    if period == 'hour'
      data
    elsif period == 'day'
      days = data.reverse.each_slice(24)
      days = days.select { |day| day.size == 24 }
      days = days.map do |daily_data|
        daily_data.inject{|sum, elem| sum + elem }
      end
      days.reverse
    end
  end

  def self.get_metrics(source, pattern, thorough = false)
    basic_auth = {
      :username => source.username,
      :password => source.password
    }
    page_offset, page_length = 0, 100
    page_data, metrics = {}, []
    while page_data.empty? || thorough && page_offset < page_data['query']['found']
      url = @@URL_ROOT + (@@METRICS_TEMPLATE % [pattern, page_offset, page_length])
      # page_data = http_get(url, source.username, source.password)
      page_data = HTTParty.get(url, :basic_auth => basic_auth)
      metrics += page_data['metrics']
      page_offset += page_length
    end
    metrics.map do |metric|
      metric['name']
    end
  end

  def self.http_get(url, username, password)
    uri = URI(url)
    response = nil
    Net::HTTP.start(uri.host, uri.port, :use_ssl => true) do |http|
      request = Net::HTTP::Get.new(uri)
      request.basic_auth(username, password)
      response = http.request(request)
    end
    JSON.load(response.body)
  end
end
