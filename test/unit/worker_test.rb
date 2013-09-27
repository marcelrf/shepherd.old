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
end
