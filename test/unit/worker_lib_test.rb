class WorkerLibTest < ActiveSupport::TestCase
  include WorkerLib

  setup :clear_redis

  def clear_redis
    $redis.flushall
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
    WorkerLib::get_queue_workers(filename)
  end

  test "get queue workers" do
    queue_workers = get_new_queue_workers
    assert queue_workers.size == 2
    assert queue_workers['queue_1'] == 1
    assert queue_workers['queue_2'] == 2
  end

  test "should do nothing" do
    WorkerLib::work('queue')
    assert $redis.keys == []
  end

  describe "dgddfg" do
    it "should do something" do
      SourceData.stub(:get_source_data) {nil}
      WorkerLib::work('queue')
      assert $redis.keys == []
    end
  end
end
