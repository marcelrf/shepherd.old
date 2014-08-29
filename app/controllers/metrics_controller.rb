class MetricsController < InheritedResources::Base
  def autocomplete
    source = Source.find(params['source'].to_i)
    metrics = SourceData.get_metrics(source, params['name'])
    metrics_html = render_to_string(
        :partial => 'autocomplete',
        :layout => false,
        :locals => {:metrics => metrics}
    )
    render :json => {
        'source' => params['source'],
        'name' => params['name'],
        'metrics' => metrics_html
    }
  end

  def create
    if params['metric_list']
        ActiveRecord::Base.transaction do
            params['metric_list'].each do |metric_name|
                params[:metric][:name] = metric_name
                Metric.create!(params[:metric])
            end
        end
        redirect_to metrics_path
    else
        @metric = Metric.new(params[:metric])
        if @metric.save
          redirect_to @metric
        else
          render "new"
        end
    end
  end
end
