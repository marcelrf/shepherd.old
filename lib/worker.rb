class Worker
  @@CHECK_DELAY = 30.minutes
  @@CHECK_PERIODS = ['hour']

  def work
    scheduled_alerts = Hash.new do |h, k|
      h[k] = Hash.new do |h, k| # first key: recipient
        h[k] = [] # second key: subject
        # value: list of alerts for that recipient and subject
      end
    end
    get_new_checks.each do |check|
      begin
        execute(check, scheduled_alerts)
      rescue Exception => e
        Rails.logger.info "[#{Time.now.utc}] WORKER ERROR: #{e.inspect}"
      end
    end
    send_alerts(scheduled_alerts)
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

  def execute(check, scheduled_alerts)
    metric, period = check['metric'], check['period']
    Rails.logger.info "[#{Time.now.utc}] WORKER: Checking #{metric.name} (#{period})."
    source_data, check_time = Cache.get_source_data(metric, period)
    analysis = DataAnalysis.get_data_analysis(source_data)
    analysis['metric'] = metric
    analysis['period'] = period
    analysis['time'] = check_time
    observation = Observation.where(:metric_id => metric.id, :period => period).first
    schedule_alerts(observation.divergence, analysis, scheduled_alerts) if observation
    (observation || Observation.new).update_attributes(analysis)
  end

  def schedule_alerts(old_divergence, analysis, scheduled_alerts)
    new_divergence = DataAnalysis.get_divergence(analysis)
    metric_alerts = Alert.where(:metric_id => analysis['metric'].id)
    metric_alerts.each do |alert|
      if alert_condition(alert.threshold, old_divergence, new_divergence)
        alert.recipient_list.each do |recipient|
          scheduled_alerts[recipient][alert.subject].push({
            :alert => alert,
            :divergence => new_divergence,
            :time => analysis['time']
          })
        end
      end
    end
  end

  def alert_condition(threshold, old_divergence, new_divergence)
    th, d1, d2 = threshold, old_divergence, new_divergence
    (
      d1 <   th && d2 >=  th ||
      d1 >  -th && d2 <= -th
    )
  end

  def send_alerts(scheduled_alerts)
    scheduled_alerts.each_pair do |recipient, recipient_info|
      recipient_info.each_pair do |subject, messages|
        Rails.logger.info "[#{Time.now.utc}] WORKER: Sending alert '#{subject}' to '#{recipient}'."
        AlertMailer.alert_email(recipient, subject, messages).deliver!
      end
    end
  end
end
