module MetricsHelper
    def source_select_options(metric)
        Source.all.map do |source|
            [source.name, source.id]
        end
    end
end
