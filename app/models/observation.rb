class Observation < ActiveRecord::Base
  attr_accessible :metric, :start, :period, :low, :median, :high, :value, :divergence, :data
  belongs_to :metric

  validates_associated :metric
  validates :start, :presence => true, :timeliness => true
  validates :period, :presence => true, inclusion: { :in =>  %w(hour day week month) }
  validates :low, :presence => true, :numericality => { :lower_than_or_equal_to => :median }
  validates :median, :presence => true, :numericality => { :higher_than_or_equal_to => :low, :lower_than_or_equal_to => :high }
  validates :high, :presence => true, :numericality => { :higher_than_or_equal_to => :median }
  validates :value, :presence => true, :numericality => true
  validates :divergence, :presence => true, :numericality => true
  validate  :date_is_start_of_period

  def to_hash
    observation_json = self.to_json
    observation_info = JSON.load(observation_json)
    observation_info.delete('id')
    observation_info.delete('created_at')
    observation_info.delete('updated_at')
    observation_info
  end

  private

  def date_is_start_of_period
    start, period = self['start'].utc, self['period']
    if period == 'hour'
      start.min == 0 && start.sec == 0 && start.nsec == 0
    elsif period == 'day'
      start.hour == 0 && start.min == 0 && start.sec == 0 && start.nsec == 0
    elsif period == 'week'
      start.wday == 1 && start.hour == 0 && start.min == 0 && start.sec == 0 && start.nsec == 0
    elsif period == 'month'
      start.day == 1 && start.hour == 0 && start.min == 0 && start.sec == 0 && start.nsec == 0
    end
  end
end
