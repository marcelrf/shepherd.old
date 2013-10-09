class WorkerTest < ActiveSupport::TestCase
  setup :setup

  def setup
    $redis.flushall
    RSpec::Mocks.setup(self)
    @worker = Worker.new
  end

  def get_new_queue_workers
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
    @worker.get_queue_workers(filename)
  end

  test "get queue workers" do
    queue_workers = get_new_queue_workers
    assert queue_workers.size == 2
    assert queue_workers['queue_1'] == 1
    assert queue_workers['queue_2'] == 2
  end

  test "work" do
    calls = 0
    @worker.stub(:work_on_queue_until_empty).with('queue') { calls += 1 }
    @worker.stub(:work_on_random_check).and_return(true, false)
    @worker.work('queue')
    assert calls == 2
  end

  test "work on queue until empty" do
    calls = []
    $redis.lpush('queue', 'check_json1')
    $redis.lpush('queue', 'check_json2')
    $redis.lpush('queue', 'check_json3')
    @worker.stub(:execute_check).with('check_json1') { calls.push(1) }
    @worker.stub(:execute_check).with('check_json2') { calls.push(2) }
    @worker.stub(:execute_check).with('check_json3') { calls.push(3) }
    @worker.work_on_queue_until_empty('queue')
    assert calls == [1, 2, 3]
    assert !$redis.rpop('queue')
  end

  test "work on random check" do
    calls = 0
    @worker.instance_variable_set(:@QUEUE_WORKERS, {'queue1' => nil, 'queue2' => nil, 'queue3' => nil})
    $redis.lpush('queue1', 'check_json1')
    $redis.lpush('queue2', 'check_json2')
    $redis.lpush('queue3', 'check_json3')
    @worker.stub(:execute_check).with('check_json1') { calls += 1 }
    @worker.stub(:execute_check).with('check_json2') { calls += 1 }
    @worker.stub(:execute_check).with('check_json3') { calls += 1 }
    @worker.work_on_random_check
    assert calls == 1
    assert $redis.llen('queue1') + $redis.llen('queue2') + $redis.llen('queue3') == 2
    @worker.work_on_random_check
    assert calls == 2
    assert $redis.llen('queue1') + $redis.llen('queue2') + $redis.llen('queue3') == 1
    @worker.work_on_random_check
    assert calls == 3
    assert $redis.llen('queue1') + $redis.llen('queue2') + $redis.llen('queue3') == 0
  end

  test "execute check" do
    @worker.stub(:json_to_check).with('check_json_1') {
      {'metric' => 'metric_1', 'start' => 'start_1', 'period' => 'period_1'}
    }
    SourceData.stub(:get_source_data).with('metric_1', 'start_1', 'period_1') {
      'source_data_1'
    }
    Bootstrapping.stub(:get_bootstrapping_analysis).with('source_data_1') {
      {'divergence' => 2}
    }
    @worker.execute_check('check_json_1')
    assert $redis.hkeys('observations') == ['check_json_1']
    assert JSON.load($redis.hget('observations', 'check_json_1')) == {'divergence' => 2}
    assert $redis.scard('done_checks') == 1
    assert $redis.spop('done_checks') == 'check_json_1'
  end

  test "json to check" do
    check_json_1 = JSON.dump({'start' => '2013-01-01T00:00:00Z+0000'})
    metric_info = {:name => 'metric_1'}
    $redis.hset('metrics', check_json_1, JSON.dump(metric_info))
    check = @worker.json_to_check(check_json_1)
    assert check['metric'].name == 'metric_1'
    assert check['start'] == Time.strptime('2013-01-01T00:00:00Z+0000', '%Y-%m-%dT%H:%M:%SZ%z').utc
  end
end
