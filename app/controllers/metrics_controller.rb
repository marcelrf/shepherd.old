class MetricsController < InheritedResources::Base
  def create
    metric_params = get_metric_params(params)
    @metric = Metric.new(metric_params)
    if @metric.save
      redirect_to @metric
    else
      render :new
    end
  end

  private

  def get_metric_params(params)
    metric_params = params[:metric]
    metric_params[:data_start] = Time.strptime(metric_params[:data_start], '%Y-%m-%d')
    metric_params
  end
end
