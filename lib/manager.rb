class Manager
  @@TIME_FORMAT = "%Y-%m-%dT%H:%M:%SZ%z"
  @@MAX_SCHEDULED_TIME = {'hour' => 3.minutes, 'day' => 15.minutes}
  @@CHECK_DELAY = 5.minutes
  @@CHECK_PERIODS = ['day']

  def initialize
    @CHECK_QUEUES = get_check_queues
  end

  def get_check_queues(filename=nil)
    filename ||= Rails.root.join('config/check_queues.yml').to_s
    check_queues = YAML.load(File.read(filename))
    check_queues.each do |queue_name, queue_infos|
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
      if metric
        observation_json = $redis.hget('observations', check_json)
        if observation_json
          observation_info = JSON.parse(observation_json)
          observation_info['metric'] = metric
          observation_info['time'] = DateTime.strptime(observation_info['time'].to_s, '%s')
          observation = (Observation.where(
            :metric_id => metric.id,
            :period => check['period']
          ).first || Observation.new)
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
    now = Time.now.utc - @@CHECK_DELAY
    checks = []
    Metric.all.each do |metric|
      @@CHECK_PERIODS.each do |period|
        check_time = TimeUtils.get_cropped_time(now, period)
        observation = Observation.where(
          :metric_id => metric.id,
          :period => period,
          :time => check_time,
        ).first
        unless observation
          checks.push({
            'metric' => metric,
            'period' => period,
          })
        end
      end
    end
    checks
  end

  def enqueue_new_checks(new_checks, checks_to_do)
    now = Time.now.utc
    count = 0
    new_checks.each do |check|
      check_json = check_to_json(check)
      unless checks_to_do.include?(check_json)
        scheduled_at = $redis.hget('scheduled_at', check_json)
        schedule_limit = now - @@MAX_SCHEDULED_TIME[check['period']]
        unless scheduled_at && Time.strptime(scheduled_at, @@TIME_FORMAT).utc > schedule_limit
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
    period = check['period']
    @CHECK_QUEUES.each do |queue_name, queue_infos|
      if queue_infos['periods'].include?(period)
        return queue_name
      end
    end
    nil
  end

  def check_to_json(check)
    JSON.dump({
      'metric' => check['metric'].id,
      'period' => check['period'],
    })
  end

  def json_to_check(check_json)
    check = JSON.load(check_json)
    check['metric'] = Metric.find(check['metric'])
    check
  end
end
