class Worker
  @@TIME_FORMAT = '%Y-%m-%dT%H:%M:%SZ%z'

  def initialize
    @QUEUE_WORKERS = get_queue_workers
  end

  def get_queue_workers(filename=nil)
    filename ||= Rails.root.join('config/check_queues.yml').to_s
    check_queues = YAML.load(File.read(filename))
    queue_workers = {}
    check_queues.each do |queue_name, queue_infos|
      queue_workers[queue_name] = queue_infos['workers']
    end
    queue_workers
  end

  def work(queue)
    loop do
      work_on_queue_until_empty(queue)
      break unless work_on_random_check
    end
  end

  def work_on_queue_until_empty(queue)
    loop do
      check_json = $redis.rpop(queue)
      if check_json
        execute_check(check_json)
      else
        break
      end
    end
  end

  def work_on_random_check
    check_json = nil
    @QUEUE_WORKERS.keys.shuffle.each do |queue|
      check_json = $redis.rpop(queue)
      break if check_json
    end
    execute_check(check_json) if check_json
    !!check_json
  end

  def execute_check(check_json)
    check = json_to_check(check_json)
    source_data, check_time = Cache.get_source_data(check['metric'], check['period'])
    analysis = DataAnalysis.get_data_analysis(source_data)
    analysis['period'] = check['period']
    analysis['time'] = check_time.to_i
    $redis.multi do
      $redis.hset('observations', check_json, JSON.dump(analysis))
      $redis.sadd('done_checks', check_json)
    end
  end

  def json_to_check(check_json)
    check = JSON.load(check_json)
    metric_json = $redis.hget('metrics', check_json)
    metric_info = JSON.load(metric_json)
    check['metric'] = Metric.new(metric_info)
    check['metric'].id = metric_info['id']
    check
  end
end
