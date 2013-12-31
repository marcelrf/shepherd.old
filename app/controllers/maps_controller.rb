class MapsController < InheritedResources::Base
  def show
    @filter = params[:filter]
    @group = params[:group]
    metrics = Metric.all.select do |metric|
      /#{@filter}/.match(metric.name)
    end
    @maps = Hash.new{|h, k| h[k] = []}
    metrics.each do |metric|
      match = /#{@group}/.match(metric.name)
      group = match ? match[1] : nil
      metric_info = [metric, metric.state(params[:period])]
      @maps[group].push(metric_info)
    end
  end
end
