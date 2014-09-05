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
        flash[:notice] = "Metrics were successfully created."
        redirect_to metrics_path
    else
        @metric = Metric.new(params[:metric])
        if @metric.save
          flash[:notice] = "Metric was successfully created."
          redirect_to metrics_path
        else
          render "new"
        end
    end
  end

  def update
    @metric = Metric.find(params[:id])
    if @metric.update_attributes(params[:metric])
      flash[:notice] = "Metric was successfully updated."
      redirect_to metrics_path
    else
      render "edit"
    end
  end
end
