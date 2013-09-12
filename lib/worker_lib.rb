module WorkerLib
  WorkerLib.extend(WorkerLib)

  include SourceData
  include Bootstrapping

  @@QUEUE_WORKERS = nil

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
    @@QUEUE_WORKERS.keys.shuffle.each do |queue|
      check_json = $redis.rpop(queue)
      break if check_json
    end
    execute_check(check_json) if check_json
    !!check_json
  end

  def execute_check(check_json)
    check = json_to_check(check_json)
    source_data = get_source_data(check['metric'], check['start'], check['period'])
    analysis = get_bootstrapping_analysis(source_data)
    $redis.multi do
      $redis.hset('observations', analysis) if analysis['divergence'].abs > 1
      $redis.sadd('done_checks', check_json)
    end
  end

  def json_to_check(check_json)
    check = JSON.load(check_json)
    metric_json = $redis.hget('metrics', check_json)
    metric_info = JSON.parse(metric_json)
    check['metric'] = Metric.new(metric_info)
    check['start'] = Time.strptime(check['start'], @@TIME_FORMAT).utc
    check
  end

  @@QUEUE_WORKERS = get_queue_workers
end
