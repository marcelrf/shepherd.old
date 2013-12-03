class MapsController < InheritedResources::Base
  def show
    period = 'hour'
    @metric_infos = Metric.all.map do |metric|
      [metric, metric.state(period)]
    end
  end
end
