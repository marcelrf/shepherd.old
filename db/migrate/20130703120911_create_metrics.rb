class CreateMetrics < ActiveRecord::Migration
  def change
    create_table :metrics do |t|
      t.string :name
      t.text :tags
      t.text :source_info
      t.string :polarity
      t.boolean :check_every_hour
      t.boolean :check_every_day
      t.boolean :check_every_week
      t.boolean :check_every_month
      t.integer :hour_check_delay
      t.integer :day_check_delay
      t.integer :week_check_delay
      t.integer :month_check_delay
      t.float :day_seasonality
      t.float :week_seasonality
      t.float :month_seasonality
      t.datetime :last_hour_check
      t.datetime :last_day_check
      t.datetime :last_week_check
      t.datetime :last_month_check
      t.datetime :data_start
      t.boolean :enabled

      t.timestamps
    end
  end
end
