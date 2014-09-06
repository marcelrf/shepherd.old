class Alert < ActiveRecord::Base
  attr_accessible :recipients, :metric_name
  belongs_to :metric
  validates :recipients, :presence => true
  validates_format_of :recipients, :with => /\A(\s*[^@\s,]+@[^@\s,]+\s*)(,\s*[^@\s,]+@[^@\s,]+\s*)*\Z/i

  def metric_name=(name)
    metric = Metric.where(:name => name).first
    if metric
      self['metric_id'] = metric.id
    else
      raise "Metric name does not match to any existing metric"
    end
  end

  def metric_name
    self.metric ? self.metric.name : ''
  end

  def recipient_list
    return self.recipients.split(',').map{|r| r.strip}
  end
end
