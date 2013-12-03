require 'time'
require 'json'

class Manager
  @@TIME_FORMAT = "%Y-%m-%dT%H:%M:%SZ%z"
  @@MAX_SCHEDULED_TIME = 10.minutes

  def initialize
    @CHECK_QUEUES = get_check_queues
  end

  def get_check_queues(filename=nil)
    filename ||= Rails.root.join('config/check_queues.yml').to_s
    check_queues = YAML.load(File.read(filename))
    check_queues.each do |queue_name, queue_infos|
      queue_infos['sources'] = queue_infos['sources'].split(' ')
      queue_infos['periods'] = queue_infos['periods'].split(' ')
    end
  end

  def get_scheduled_checks
    checks = $redis.multi do
      @CHECK_QUEUES.keys.each do |queue|
        $redis.lrange(queue, 0, -1)
      end
      $redis.smembers('done_checks')
    end
    [checks[0...-1].flatten, checks[-1]]
  end

  def process_done_checks(done_checks)
    registered = register_done_checks(done_checks)
    remove_check_data(done_checks)
    registered
  end

  def register_done_checks(done_checks)
    registered = 0
    done_checks.each do |check_json|
      check = json_to_check(check_json)
      metric = check['metric']
      check_start = check['start']
      check_period = check['period']
      if metric
        # get observation data
        observation_json = $redis.hget('observations', check_json)
        if observation_json
          observation_info = JSON.parse(observation_json)
          observation_info['metric'] = metric
          observation_info['start'] = check_start
          observation_info['period'] = check_period
          # create or update metric observation
          observation = (Observation.where(
            :metric_id => metric.id,
            :start => check_start,
            :period => check_period
          )[0] || Observation.new)
          updated = observation.update_attributes(observation_info)
          registered += 1 if updated
        end
      end
    end
    registered
  end

  def remove_check_data(done_checks)
    done_checks.each do |check_json|
      $redis.multi do
        @CHECK_QUEUES.keys.each do |queue|
          $redis.lrem(queue, 0, check_json)
        end
        $redis.srem('done_checks', check_json)
        $redis.hdel('metrics', check_json)
        $redis.hdel('observations', check_json)
        $redis.hdel('scheduled_at', check_json)
      end
    end
  end

  def schedule_new_checks(checks_to_do)
    new_checks = get_new_checks
    enqueue_new_checks(new_checks, checks_to_do)
  end

  def get_new_checks
    now = Time.now.utc
    checks = []
    metrics = Metric.all
    metrics.each do |metric|
      delayed_now = now - metric.check_delay * 1.minute
      metric.periods.each do |period|
        check_start = crop_time(delayed_now, period) - 1.send(period)
        observation = Observation.where(
          :metric_id => metric.id,
          :period => period,
          :start => check_start,
        ).first
        unless observation
          checks.push({
            'metric' => metric,
            'start' => check_start,
            'period' => period,
          })
        end
      end
    end
    checks
  end

  def crop_time(time, crop_until)
    if crop_until == 'hour'
      Time.new(time.year, time.month, time.day, time.hour, 0, 0, 0).utc
    elsif crop_until == 'day'
      Time.new(time.year, time.month, time.day, 0, 0, 0, 0).utc
    elsif crop_until == 'week'
      last_day = Time.new(time.year, time.month, time.day, 0, 0, 0, 0).utc
      last_day - ((last_day.wday - 1) % 7) * 1.day
    elsif crop_until == 'month'
      Time.new(time.year, time.month, 1, 0, 0, 0, 0).utc
    end
  end

  def enqueue_new_checks(new_checks, checks_to_do)
    now = Time.now.utc
    count = 0
    new_checks.each do |check|
      check_json = check_to_json(check)
      unless checks_to_do.include?(check_json)
        scheduled_at = $redis.hget('scheduled_at', check_json)
        unless scheduled_at && Time.strptime(scheduled_at, @@TIME_FORMAT).utc > now - @@MAX_SCHEDULED_TIME
          queue_key = get_queue_key(check)
          $redis.multi do
            $redis.lpush(queue_key, check_json)
            $redis.hset('metrics', check_json, check['metric'].to_hash.to_json)
            $redis.hset('scheduled_at', check_json, now.strftime(@@TIME_FORMAT))
          end
          count += 1
        end
      end
    end
    count
  end

  def get_queue_key(check)
    now = Time.now.utc
    metric = check['metric']
    source = metric.get_source_info['name']
    period = check['period']
    start_time = check['start']
    period_time = 1.send(period)
    end_time = start_time + period_time
    delay = metric.check_delay
    history = (now - end_time - delay) / period_time > 1
    @CHECK_QUEUES.each do |queue_name, queue_infos|
      if (queue_infos['sources'].include?(source) &&
          queue_infos['periods'].include?(period) &&
          (!history || queue_infos['history']))
        return queue_name
      end
    end
    nil
  end

  def check_to_json(check)
    JSON.dump({
      'metric' => check['metric'].id,
      'start' => check['start'].strftime(@@TIME_FORMAT),
      'period' => check['period'],
    })
  end

  def json_to_check(check_json)
    check = JSON.load(check_json)
    check['metric'] = Metric.find(check['metric'])
    check['start'] = Time.strptime(check['start'], @@TIME_FORMAT).utc
    check
  end
end
