namespace :metrics do
  desc "Makes Shepherd start to watch the passed metrics"
  task :watch, [:user, :pass, :pattern, :polarity] => :environment do |t, args|
    librato_delay = 5 # in minutes
    polarity = args[:polarity].nil? ? 'positive' : args[:polarity]
    librato_metrics = SourceData.get_metrics_from_librato(args[:user], args[:pass], args[:pattern])
    librato_metrics.each do |librato_metric|
      metric_name = librato_metric['name']
      existing = Metric.where('name' => metric_name)
      if existing.count == 0
        puts "Watching #{metric_name}"
        Metric.create!(
          :name => metric_name,
          :polarity => polarity,
          :check_every_hour => true,
          :check_every_day => true,
          :check_every_week => true,
          :check_every_month => true,
          :hour_check_delay => librato_delay,
          :day_check_delay => librato_delay,
          :week_check_delay => librato_delay,
          :month_check_delay => librato_delay,
          :data_start => Time.new(2000, 1, 1, 0, 0, 0, 0).utc,
          :enabled => true,
          :source_info => JSON.dump({
            'name' => 'librato',
            'metric' => metric_name,
            'username' => args[:user],
            'password' => args[:pass]
          })
        )
      end
    end
  end

  desc "Makes Shepherd stop watching the passed metrics"
  task :unwatch, [:regexp] => :environment do |t, args|
    regexp = Regexp.new(args[:regexp])
    Metric.all.each do |metric|
      metric_name = metric.source_info['metric']
      if regexp.match(metric_name)
        puts "Unwatching #{metric_name}"
        Metric.destroy(metric.id)
      end
    end
  end

  desc "Lists all the metrics being watched by Shepherd"
  task :watched, [:regexp] => :environment do |t, args|
    regexp = args[:regexp].nil? ? nil : Regexp.new(args[:regexp])
    Metric.all.each do |metric|
      metric_name = metric.source_info['metric']
      if regexp.nil? || regexp.match(metric_name)
        puts "Watched #{metric_name}"
      end
    end
  end 
end
