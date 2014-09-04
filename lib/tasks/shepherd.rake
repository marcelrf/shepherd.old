namespace :shepherd do
  desc "Shows the worker's status"
  task :status => :environment do |t, args|
    execute_task('daemon:worker:status')
  end  

  desc "Starts the worker"
  task :start => :environment do |t, args|
    execute_task('daemon:worker:start')
  end

  desc "Stops the worker"
  task :stop => :environment do |t, args|
    execute_task('daemon:worker:stop')
  end

  desc "Clears cache and deletes all observations"
  task :clear => :environment do |t, args|
    $redis.flushall
    Observation.delete_all
  end

  desc "Clears cache and observation data and restarts the worker"
  task :restart => :environment do |t, args|
    execute_task('shepherd:stop')
    execute_task('shepherd:clear')
    execute_task('shepherd:start')
  end

  desc "Check the given metric for a given period"
  task :check, [:metric, :period] => :environment do |t, args|
    metric = Metric.where(:name => args[:metric]).first
    if metric
      source_data, last_measure = Cache.get_source_data(metric, args['period'])
      analysis = DataAnalysis.get_data_analysis(source_data)
      analysis['divergence'] = DataAnalysis.get_divergence(analysis)
      analysis['time'] = last_measure
      print_analysis(analysis)
    else
      puts "Metric '#{args[:metric]}' not found"
    end
  end

  def execute_task(name)
    task = Rake::Task[name]
    task.reenable
    task.invoke
  end

  def print_analysis(analysis)
    puts '======================='
    print analysis['time'], "\n"
    puts '-----------------------'
    print 'low:    ', analysis['low'].round(2), "\n"
    print 'median: ', analysis['median'].round(2), "\n"
    print 'high:   ', analysis['high'].round(2), "\n"
    print 'value:  ', analysis['value'].round(2), "\n"
    puts '-----------------------'
    print 'divergence: ', round_significant(analysis['divergence'], 2), "\n"
    puts '======================='
  end

  def round_significant(value, digits)
    Float("%.#{digits}g" % value)
  end
end
