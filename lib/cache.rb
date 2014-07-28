class Cache
  @@TIME_FORMAT = '%Y-%m-%dT%H:%M:%SZ%z'
  @@MAX_VALUES = 2000
  @@CHECK_DELAY = 25.minutes

  def self.get_source_data(metric, period)
    now = Time.now.utc - @@CHECK_DELAY
    end_time = TimeUtils.get_cropped_time(now, period)
    cache_key = get_cache_key(metric, period)
    cache_data_json = $redis.get(cache_key)
    if cache_data_json
      cache_data = JSON.load(cache_data_json)
      start_time = Time.parse(cache_data['last_measured'], @@TIME_FORMAT).utc
      new_data = SourceData.get_source_data(metric, period, start_time, end_time)
      source_data = (cache_data['values'] + new_data)[-@@MAX_VALUES..-1]
    else
      start_time = end_time - @@MAX_VALUES.send(period)
      source_data = SourceData.get_source_data(metric, period, start_time, end_time)
      puts source_data.size
    end
    cache_data_json = JSON.dump({
        'last_measured' => end_time,
        'values' => source_data
    })
    $redis.set(cache_key, cache_data_json)
    [source_data, end_time]
  end

  def self.get_cache_key(metric, period)
    JSON.dump({
      'namespace' => 'source_data',
      'metric' => metric.id,
      'period' => period
    })
  end
end
