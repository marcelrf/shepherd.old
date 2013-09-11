class Observation < ActiveRecord::Base
  attr_accessible :metric, :start, :end, :low, :median, :high, :value, :divergence
  belongs_to :metric

  validates_associated :metric
  validates :start, :presence => true, :timeliness => true
  validates :end, :presence => true, :timeliness => true
  validates :low, :presence => true, :numericality => { :lower_than_or_equal_to => :median }
  validates :median, :presence => true, :numericality => { :higher_than_or_equal_to => :low, :lower_than_or_equal_to => :high }
  validates :high, :presence => true, :numericality => { :higher_than_or_equal_to => :median }
  validates :value, :presence => true, :numericality => true
  validates :divergence, :presence => true, :numericality => true
  validate  :dates_are_not_overlapping

  def to_hash
    observation_json = self.to_json
    observation_info = JSON.load(observation_json)
    observation_info.delete('id')
    observation_info.delete('created_at')
    observation_info.delete('updated_at')
    observation_info
  end

  private

  def dates_are_not_overlapping
    true
  end
end
