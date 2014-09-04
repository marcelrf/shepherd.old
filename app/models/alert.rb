class Alert < ActiveRecord::Base
  attr_accessible :recipients
  belongs_to :metric
  validates :recipients, :presence => true
  validates_format_of :recipients, :with => /\A(\s*[^@\s,]+@[^@\s,]+\s*)(,\s*[^@\s,]+@[^@\s,]+\s*)*\Z/i
end
