class WorkerLibTest < ActiveSupport::TestCase
  include WorkerLib

  setup :clear_redis

  def clear_redis
    $redis.flushall
  end
end
