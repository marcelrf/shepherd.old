class Observation < ActiveRecord::Base
  attr_accessible :metric, :time, :period, :low, :median, :high, :value, :data
  belongs_to :metric

  validates_associated :metric
  validates :time, :presence => true, :timeliness => true
  validates :period, :presence => true, inclusion: { :in =>  %w(hour day week month) }
  validates :low, :presence => true, :numericality => { :lower_than_or_equal_to => :median }
  validates :median, :presence => true, :numericality => { :higher_than_or_equal_to => :low, :lower_than_or_equal_to => :high }
  validates :high, :presence => true, :numericality => { :higher_than_or_equal_to => :median }
  validates :value, :presence => true, :numericality => true

  def to_hash
    observation_json = self.to_json
    observation_info = JSON.load(observation_json)
    observation_info.delete('created_at')
    observation_info.delete('updated_at')
    observation_info
  end
end
