class Worker
  @@CHECK_DELAY = 30.minutes
  @@CHECK_PERIODS = ['hour']

  def work
    get_new_checks.each do |check|
      begin
        execute(check)
      rescue Exception => e
        Rails.logger.info "[#{Time.now.utc}] WORKER ERROR: #{e}"
      end
    end
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
          checks.push({'metric' => metric, 'period' => period})
        end
      end
    end
    checks
  end

  def execute(check)
    metric, period = check['metric'], check['period']
    Rails.logger.info "[#{Time.now.utc}] WORKER: Checking #{metric.name} (#{period})."
    source_data, check_time = Cache.get_source_data(metric, period)
    analysis = DataAnalysis.get_data_analysis(source_data)
    analysis['metric'] = metric
    analysis['period'] = period
    analysis['time'] = check_time
    observation = Observation.where(:metric_id => metric.id, :period => period).first
    (observation || Observation.new).update_attributes(analysis)
  end
end
