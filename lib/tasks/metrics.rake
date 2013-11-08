namespace :metrics do
  desc "Makes the system start to watch the metrics passed"
  task :watch, [:user, :pass, :regexp] => :environment do |t, args|
    ###
  end

  desc "Makes the system stop to watch the passed metrics"
  task :unwatch, [:regexp] => :environment do |t, args|
    regexp = Regexp.new(args[:regexp])
    Metric.all.each do |metric|
      if regexp.match(metric.source_info['metric'])
        puts "Unwatching #{metric.source_info['metric']}"
        Metric.destroy(metric.id)
      end
    end
  end
end
