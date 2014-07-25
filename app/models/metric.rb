class Metric < ActiveRecord::Base
  attr_accessible :name, :polarity, :kind
  has_many :observations
  belongs_to :source

  validates :name, :presence => true, :length => { :minimum => 2 }
  validates :polarity, :presence => true, inclusion: { :in =>  %w(positive negative) }
  validates :kind, :presence => true, inclusion: { :in =>  %w(counter gauge) }

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
