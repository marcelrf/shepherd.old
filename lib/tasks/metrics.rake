namespace :metrics do
  desc "Makes the system start to watch the metrics passed"
  task :watch, [:user, :pass, :pattern, :polarity] => :environment do |t, args|
    args[:polarity] = 'positive' if args[:polarity].nil?
    librato_metrics = SourceData.get_metrics_from_librato(args[:user], args[:pass], args[:pattern])
    librato_metrics.each do |librato_metric|
      metric_name = librato_metric['name']
      existing = Metric.where('name' => metric_name)
      if existing.count == 0
        puts "Watching #{metric_name} #{args[:polarity]}"
        # Metric.create!(
        #   :name => metric_name
        # )
      end
    end
  end

  desc "Makes the system stop to watch the passed metrics"
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
end
