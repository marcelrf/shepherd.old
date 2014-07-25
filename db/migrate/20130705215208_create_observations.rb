class CreateObservations < ActiveRecord::Migration
  def change
    create_table :observations do |t|
      t.references :metric
      t.datetime :time
      t.string :period
      t.float :low
      t.float :median
      t.float :high
      t.float :value
      t.string :data

      t.timestamps
    end
  end
end
