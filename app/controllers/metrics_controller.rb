class MetricsController < InheritedResources::Base
  def autocomplete
    source = Source.find(params['source'].to_i)
    metrics = SourceData.get_metrics(source, params['name'])
    render :json => {
        'source' => params['source'],
        'name' => params['name'],
        'metrics' => metrics
    }
  end
end
