class Worker
  @@CHECK_DELAY = 30.minutes
  @@CHECK_PERIODS = ['hour']
  @@ALERT_THRESHOLD = 3

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
    alert_if_necessary(observation.divergence, analysis) if observation
    (observation || Observation.new).update_attributes(analysis)
  end

  def alert_if_necessary(old_divergence, analysis)
    new_divergence = DataAnalysis.get_divergence(analysis)
    d1, d2 = old_divergence, new_divergence
    th = @@ALERT_THRESHOLD
    # alert condition
    if (d1 <   th && d2 >=  th ||
        d1 >  -th && d2 <= -th ||
        d1 >=  th && d2 <   1  ||
        d1 <= -th && d2 >  -1)
      # send alerts
      Rails.logger.info "[#{Time.now.utc}] WORKER: Sending alerts for #{analysis['metric'].name}."
      alerts = Alert.where(:metric_id => analysis['metric'].id)
      alerts.each do |alert|
        AlertMailer.alert_email(alert, new_divergence, analysis['time']).deliver!
      end
    end
  end
end
