class Metric < ActiveRecord::Base
  attr_accessible :name, :source_info, :polarity, :check_every, :check_delay
  has_many :observations

  validates :name, :presence => true, :length => { :minimum => 2 }
  validates :polarity, :presence => true, inclusion: { :in =>  %w(positive negative) }
  validates :check_every, :presence => true, inclusion: { :in =>  %w(hour day week month) }
  validates :check_delay, :numericality => { :only_integer => true, :greater_than_or_equal_to => 0}, :allow_nil => true

  def get_source_info
    JSON.load(self['source_info'])
  end

  def set_source_info(source_info)
    self['source_info'] = JSON.dump(source_info)
  end

  def periods
    all_periods = ['hour', 'day', 'week', 'month']
    metric_period_index = all_periods.index(self['check_every'])
    all_periods[metric_period_index..-1]
  end

  def state(period)
    observations = Observation.where(:metric_id => self['id'], :period => period)
    observations.sort_by{|observation| observation.start}[-1]
  end

  def to_hash
    metric_json = self.to_json
    metric_info = JSON.load(metric_json)
    metric_info.delete('created_at')
    metric_info.delete('updated_at')
    metric_info
  end
end
