class MapsController < InheritedResources::Base
  @@WITH_MARGIN = 43
  @@HEIGHT_MARGIN = 115

  def show
    @filter = params[:filter]
    @group = params[:group]
    @width = params[:width] ? params[:width].to_i - @@WITH_MARGIN : nil
    @height = params[:height] ? params[:height].to_i - @@HEIGHT_MARGIN : nil
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
