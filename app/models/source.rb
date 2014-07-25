class Source < ActiveRecord::Base
  attr_accessible :name, :username, :password
  has_many :metrics

  validates :name, :presence => true, :length => { :minimum => 2 }
  validates :username, :presence => true, :length => { :minimum => 2 }
  validates :password, :presence => true, :length => { :minimum => 2 }
end
