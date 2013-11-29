class MapsController < InheritedResources::Base
  def show
    @metric_info = Metric.all.map do |metric|
      hour_observations = metric.observations.select do |obs|
        obs.period == 'hour'
      end.sort_by {|observation| observation.start}
      last_observation = hour_observations.size > 0 ? hour_observations[-1] : nil
      [metric.name, last_observation ? last_observation.divergence : 0]
    end
  end
end
