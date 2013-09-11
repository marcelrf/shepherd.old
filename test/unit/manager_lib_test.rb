class ManagerLibTest < ActiveSupport::TestCase
  include ManagerLib

  setup :clear_redis

  def clear_redis
    $redis.flushall
  end  

  def get_new_check(metric, period)
    last_check = metric.send("last_#{period}_check")
    check_start = last_check + 1.send(period)
    {
      'metric' => metric,
      'start' => check_start,
      'period' => period,
    }
  end

  def get_new_observation(metric, check)
    now = Time.now.utc
    Observation.new({
      :metric => metric,
      :start => check['start'],
      :end => check['start'] + 1.send(check['period']),
      :low => 1,
      :median => 2,
      :high => 3,
      :value => 4,
      :divergence => 2,
    })
  end

  def get_new_check_queues
    filename = Rails.root.join('tmp/check_queues_test.yml').to_s
    File.open(filename, 'w') do |file|
      file.write("""
        queue_1:
          sources: source_1
          periods: hour
          history: false
          workers: 1
        queue_2:
          sources: source_1 source_2
          periods: day week month
          history: true
          workers: 2
      """)
    end
    get_check_queues(filename)
  end
  
  test "get check queues" do
    check_queues = get_new_check_queues
    assert check_queues.size == 2
    assert check_queues['queue_1'] == {
      'sources' => ['source_1'],
      'periods' => ['hour'],
      'history' => false,
      'workers' => 1,
    }
    assert check_queues['queue_2'] == {
      'sources' => ['source_1', 'source_2'],
      'periods' => ['day', 'week', 'month'],
      'history' => true,
      'workers' => 2,
    }
  end

  test "get scheduled checks" do
    $redis.lpush('queue1', 'elem1')
    $redis.lpush('queue2', 'elem2')
    $redis.lpush('queue3', 'elem3')
    $redis.sadd('done_checks', 'elem4')
    $redis.sadd('done_checks', 'elem5')
    @@CHECK_QUEUES = {'queue1' => nil, 'queue2' => nil, 'queue3' => nil}
    checks_to_do, done_checks = get_scheduled_checks
    assert Set.new(checks_to_do) == Set.new(['elem1', 'elem2', 'elem3'])
    assert Set.new(done_checks) == Set.new(['elem4', 'elem5'])
  end

  test "register done checks" do
    metric_1 = metrics(:scheduling_lib_test_1)
    metric_2 = metrics(:scheduling_lib_test_2)
    check_1 = get_new_check(metric_1, 'hour')
    check_2 = get_new_check(metric_2, 'month')
    check_json_1 = check_to_json(check_1)
    check_json_2 = check_to_json(check_2)
    observation = get_new_observation(metric_1, check_1)
    $redis.hset('observations', check_json_1, observation.to_hash.to_json)
    registered, observed = register_done_checks([check_json_1, check_json_2])
    assert registered == 2
    assert Metric.find(metric_1.id).last_hour_check == check_1['start']
    assert Metric.find(metric_2.id).last_month_check == check_2['start']
    assert observed == 1
    assert Observation.where(:metric_id => metric_1.id).count == 1
  end

  test "remove check data" do
    now_text = Time.now.utc.strftime(@@TIME_FORMAT)
    metric_1 = metrics(:scheduling_lib_test_1)
    metric_2 = metrics(:scheduling_lib_test_2)
    check_1 = get_new_check(metric_1, 'hour')
    check_2 = get_new_check(metric_2, 'month')
    check_json_1 = check_to_json(check_1)
    check_json_2 = check_to_json(check_2)
    observation_1 = get_new_observation(metric_1, check_1)
    $redis.lpush('queue_1', check_json_1)
    $redis.lpush('queue_2', check_json_2)
    $redis.sadd('done_checks', check_json_1)
    $redis.hset('scheduled_at', check_json_1, now_text)
    $redis.hset('scheduled_at', check_json_2, now_text)
    $redis.hset('metrics', check_json_1, metric_1.to_hash.to_json)
    $redis.hset('metrics', check_json_2, metric_2.to_hash.to_json)
    $redis.hset('observations', check_json_1, observation_1.to_hash.to_json)
    @@CHECK_QUEUES = {'queue_1' => nil, 'queue_2' => nil}
    remove_check_data([check_json_1])
    assert $redis.llen('queue_1') == 0
    assert $redis.llen('queue_2') == 1
    assert $redis.lindex('queue_2', 0) == check_json_2
    assert $redis.scard('done_checks') == 0
    assert $redis.hlen('scheduled_at') == 1
    assert $redis.hget('scheduled_at', check_json_2) == now_text
    assert $redis.hlen('metrics') == 1
    assert $redis.hget('metrics', check_json_2) == metric_2.to_hash.to_json
    assert $redis.hlen('observations') == 0
  end

  test "get new checks" do
    new_checks = get_new_checks
    assert new_checks.count == 3
    assert new_checks[0]['metric'] = metrics(:scheduling_lib_test_1)
    assert new_checks[0]['start'] = Time.new(2012, 10, 1, 1, 0, 0, 0)
    assert new_checks[0]['period'] = 'hour'
    assert new_checks[1]['metric'] = metrics(:scheduling_lib_test_2)
    assert new_checks[1]['start'] = Time.new(2012, 11, 1, 0, 0, 0, 0)
    assert new_checks[1]['period'] = 'month'
    assert new_checks[2]['metric'] = metrics(:scheduling_lib_test_3)
    assert new_checks[2]['start'] = Time.new(2012, 11, 1, 0, 0, 0, 0)
    assert new_checks[2]['period'] = 'month'
  end

  test "get queue key" do
    @@CHECK_QUEUES = get_new_check_queues
    metric_1 = metrics(:scheduling_lib_test_1)
    check_1 = get_new_check(metric_1, 'hour')
    check_1['start'] = crop_time(Time.now.utc, 'hour') - 1.hour
    queue_key_1 = get_queue_key(check_1)
    assert queue_key_1 == 'queue_1'
    metric_2 = metrics(:scheduling_lib_test_2)
    check_2 = get_new_check(metric_2, 'month')
    check_2['start'] = crop_time(Time.now.utc, 'month') - 10.months
    queue_key_2 = get_queue_key(check_2)
    assert queue_key_2 == 'queue_2'
  end

  test "enqueue new checks" do
    now = Time.now.utc
    @@CHECK_QUEUES = get_new_check_queues
    metric_1 = metrics(:scheduling_lib_test_1)
    metric_2 = metrics(:scheduling_lib_test_2)
    metric_3 = metrics(:scheduling_lib_test_3)
    check_1 = get_new_check(metric_1, 'hour')
    check_2 = get_new_check(metric_2, 'month')
    check_3 = get_new_check(metric_3, 'month')
    check_json_1 = check_to_json(check_1)
    check_json_2 = check_to_json(check_2)
    check_json_3 = check_to_json(check_3)
    $redis.lpush('queue_1', check_json_1)
    $redis.hset('scheduled_at', check_json_1, now.strftime(@@TIME_FORMAT))
    $redis.hset('scheduled_at', check_json_2, (now - 10.day).strftime(@@TIME_FORMAT))
    enqueue_new_checks([check_1, check_2, check_3], [check_json_1])
    assert $redis.llen('queue_1') == 1
    assert $redis.lindex('queue_1', 0) == check_json_1
    assert $redis.llen('queue_2') == 2
    assert $redis.lindex('queue_2', 1) == check_json_2
    assert $redis.lindex('queue_2', 0) == check_json_3
    assert $redis.hget('metrics', check_json_2) == metric_2.to_hash.to_json
    assert $redis.hget('metrics', check_json_3) == metric_3.to_hash.to_json
    assert Time.strptime($redis.hget('scheduled_at', check_json_2), @@TIME_FORMAT).utc.to_i >= now.to_i
    assert Time.strptime($redis.hget('scheduled_at', check_json_3), @@TIME_FORMAT).utc.to_i >= now.to_i
  end
end
