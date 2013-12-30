class MapsController < InheritedResources::Base
  def show
    @filter = params[:filter]
    @group = params[:group]
    metrics = Metric.where("name like ?", "%#{@filter}%")
    @metric_infos = Hash.new{|h, k| h[k] = []}
    metrics.each do |metric|
      match = /#{@group}/.match(metric.name)
      group = match ? match[1] : nil
      metric_info = [metric, metric.state(params[:period])]
      @metric_infos[group].push(metric_info)
    end
  end
end
