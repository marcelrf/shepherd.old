namespace :shepherd do
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
  task :unwatch, [:pattern] => :environment do |t, args|
    pattern = Regexp.new(args[:pattern])
    Metric.all.each do |metric|
      metric_name = metric.source_info['metric']
      if pattern.match(metric_name)
        puts "Unwatching #{metric_name}"
        Metric.destroy(metric.id)
      end
    end
  end

  desc "Lists all the metrics being watched by Shepherd"
  task :watched, [:pattern] => :environment do |t, args|
    pattern = args[:pattern].nil? ? nil : Regexp.new(args[:pattern])
    Metric.all.each do |metric|
      metric_name = metric.source_info['metric']
      if pattern.nil? || pattern.match(metric_name)
        puts "Watched #{metric_name}"
      end
    end
  end

  desc "Lists all the metrics NOT being watched by Shepherd"
  task :unwatched, [:user, :pass, :pattern] => :environment do |t, args|
    librato_metrics = SourceData.get_metrics_from_librato(args[:user], args[:pass], args[:pattern])
    librato_metrics.each do |librato_metric|
      metric_name = librato_metric['name']
      found_metrics = Metric.where(:name => metric_name)
      puts "Unwatched #{metric_name}" if found_metrics.count == 0
    end
  end

  desc "Shows the status of all Shepherd daemons"
  task :status => :environment do |t, args|
    execute_task('daemon:manager:status')
    execute_task('daemon:worker:status')
  end  

  desc "Starts all Shepherd daemons"
  task :start => :environment do |t, args|
    execute_task('daemon:manager:start')
    sleep(3)
    execute_task('daemon:worker:start')
  end

  desc "Stops all Shepherd daemons"
  task :stop => :environment do |t, args|
    execute_task('daemon:manager:stop')
    execute_task('daemon:worker:stop')
  end

  desc "Clears cache, deletes all observations and all metrics last-check data"
  task :forget => :environment do |t, args|
    Metric.all.each do |metric|
      metric.last_hour_check = nil
      metric.last_day_check = nil
      metric.last_week_check = nil
      metric.last_month_check = nil
    end
    $redis.flushall
    Observation.delete_all
  end

  desc "Clears cache and observation data and restarts all Shepherd daemons"
  task :respawn => :environment do |t, args|
    execute_task('shepherd:stop')
    execute_task('shepherd:forget')
    execute_task('shepherd:start')
  end

  desc "Check the given metric for a given period"
  task :check, [:metric, :start, :period] => :environment do |t, args|
    metric = Metric.where(:name => args[:metric])[0]
    start = Time.parse(args[:start]).utc
    if metric && start
      source_data = SourceData.get_source_data(metric, start, args['period'])
      analysis = Bootstrapping.get_bootstrapping_analysis(source_data, args['period'])
      puts analysis
    else
      puts "Metric '#{args[:metric]}' not found" unless metric
      puts "Not able to parse start date '#{args[:start]}'" unless start
    end
  end

  def execute_task(name)
    task = Rake::Task[name]
    task.reenable
    task.invoke
  end
end
