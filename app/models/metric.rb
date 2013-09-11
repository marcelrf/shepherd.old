class Metric < ActiveRecord::Base
  attr_accessible :name, :tags, :source_info, :polarity, :check_every_hour, :check_every_day, :check_every_week, :check_every_month, :hour_check_delay, :day_check_delay, :week_check_delay, :month_check_delay, :day_seasonality, :week_seasonality, :month_seasonality, :last_hour_check, :last_day_check, :last_week_check, :last_month_check, :data_start, :enabled
  has_many :observations

  validates :name, :presence => true, :length => { :minimum => 2 }
  validates :tags, :format => { :with => /\A([^,]+(,[^,]+)*)?\z/ }
  validate  :source_info_is_correct
  validates :polarity, :presence => true, inclusion: { :in =>  %w(positive negative) }
  validates :hour_check_delay, :numericality => { :only_integer => true, :greater_than_or_equal_to => 0}, :allow_nil => true
  validates :day_check_delay, :numericality => { :only_integer => true, :greater_than_or_equal_to => 0}, :allow_nil => true
  validates :week_check_delay, :numericality => { :only_integer => true, :greater_than_or_equal_to => 0}, :allow_nil => true
  validates :month_check_delay, :numericality => { :only_integer => true, :greater_than_or_equal_to => 0}, :allow_nil => true
  validates :day_seasonality, :presence => true, :numericality => { :greater_than_or_equal_to => 0, :less_than_or_equal_to => 1 }
  validates :week_seasonality, :presence => true, :numericality => { :greater_than_or_equal_to => 0, :less_than_or_equal_to => 1 }
  validates :month_seasonality, :presence => true, :numericality => { :greater_than_or_equal_to => 0, :less_than_or_equal_to => 1 }
  validates :last_hour_check, :timeliness => { :type => :time }, :allow_nil => true
  validates :last_day_check, :timeliness => { :type => :time }, :allow_nil => true
  validates :last_week_check, :timeliness => { :type => :time }, :allow_nil => true
  validates :last_month_check, :timeliness => { :type => :time }, :allow_nil => true
  validates :data_start, :presence => true, :timeliness => { :type => :time }

  def check_every
    checks = []
    checks.push('hour') if self.check_every_hour
    checks.push('day') if self.check_every_day
    checks.push('week') if self.check_every_week
    checks.push('month') if self.check_every_month
    checks
  end

  def last_check
    last_checks = [
      self.last_hour_check,
      self.last_day_check,
      self.last_week_check,
      self.last_month_check
    ]
    last_checks.select{|timestamp| timestamp}.max
  end

  def seasonalities
    seasonalities = []
    seasonalities.push('day') if self.day_seasonality > 0
    seasonalities.push('week') if self.week_seasonality > 0
    seasonalities.push('month') if self.month_seasonality > 0
    seasonalities
  end

  def source
    source_info_json = self['source_info']
    JSON.parse(source_info_json)['source']
  end

  def to_hash
    metric_json = self.to_json
    metric_info = JSON.load(metric_json)
    metric_info.delete('id')
    metric_info.delete('created_at')
    metric_info.delete('updated_at')
    metric_info
  end

  private

  def source_info_is_correct
    true
  end
end
