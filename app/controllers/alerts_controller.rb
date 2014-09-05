class AlertsController < InheritedResources::Base
  def autocomplete
    metrics = Metric.where("name LIKE '%#{params[:name]}%'").map do |metric|
        metric.name
    end
    metrics_html = render_to_string(
        :partial => 'metrics/autocomplete',
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
                params[:alert][:metric_name] = metric_name
                Alert.create!(params[:alert])
            end
        end
        flash[:notice] = "Alerts were successfully created."
        redirect_to alerts_path
    else
        @alert = Alert.new(params[:metric])
        if @alert.save
          flash[:notice] = "Alert was successfully created."
          redirect_to alerts_path
        else
          render "new"
        end
    end
  end

  def update
    @alert = Alert.find(params[:id])
    if @alert.update_attributes(params[:alert])
      flash[:notice] = "Alert was successfully updated."
      redirect_to alerts_path
    else
      render "edit"
    end
  end
end
