class MapsController < InheritedResources::Base
  def show
    @metric_infos = Metric.all.map do |metric|
      [metric, metric.state(params[:period])]
    end
  end
end
