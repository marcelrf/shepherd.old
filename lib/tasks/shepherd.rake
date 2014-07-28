namespace :shepherd do
  desc "Makes Shepherd start to watch the passed metrics"
  task :watch, [:user, :pass, :pattern, :polarity, :kind] => :environment do |t, args|
    librato_delay = 45 # in minutes
    polarity = args[:polarity].nil? ? 'positive' : args[:polarity]
    kind = args[:kind].nil? ? 'counter' : args[:kind]
    librato_metrics = SourceData.get_metrics_from_librato(args[:user], args[:pass], args[:pattern])
    librato_metrics.each do |librato_metric|
      metric_name = librato_metric['name']
      existing = Metric.where('name' => metric_name)
      if existing.count == 0
        puts "Watching #{polarity} #{kind} #{metric_name}"
        Metric.create(
          :name => metric_name,
          :polarity => polarity,
          :check_every => 'hour',
          :check_delay => librato_delay,
          :kind => kind,
          :source_info => JSON.dump({
            'name' => 'librato',
            'metric' => metric_name,
            'username' => args[:user],
            'password' => args[:pass]
          }),
        )
      end
    end
  end

  desc "Makes Shepherd stop watching the passed metrics"
  task :unwatch, [:pattern] => :environment do |t, args|
    pattern = Regexp.new(args[:pattern])
    Metric.all.each do |metric|
      metric_name = metric.get_source_info['metric']
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
      metric_name = metric.get_source_info['metric']
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

  desc "Clears cache and deletes all observations"
  task :clear => :environment do |t, args|
    $redis.flushall
    Observation.delete_all
  end

  desc "Clears cache and observation data and restarts all Shepherd daemons"
  task :restart => :environment do |t, args|
    execute_task('shepherd:stop')
    execute_task('shepherd:clear')
    execute_task('shepherd:start')
  end

  desc "Check the given metric for a given period"
  task :check, [:metric, :period] => :environment do |t, args|
    puts "starting"
    metric = Metric.where(:name => args[:metric]).first
    if metric
      source_data, last_measure = Cache.get_source_data(metric, args['period'])
      analysis = DataAnalysis.get_data_analysis(source_data)
      puts analysis, last_measure
    else
      puts "Metric '#{args[:metric]}' not found"
    end
  end

  def execute_task(name)
    task = Rake::Task[name]
    task.reenable
    task.invoke
  end
end
