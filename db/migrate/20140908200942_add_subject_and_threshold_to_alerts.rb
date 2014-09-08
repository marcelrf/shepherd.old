class AddSubjectAndThresholdToAlerts < ActiveRecord::Migration
  def change
    add_column :alerts, :subject, :string
    add_column :alerts, :threshold, :integer
  end
end
