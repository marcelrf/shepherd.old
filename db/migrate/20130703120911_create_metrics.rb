class CreateMetrics < ActiveRecord::Migration
  def change
    create_table :metrics do |t|
      t.string :name
      t.text :source_info
      t.string :polarity
      t.boolean :check_every
      t.integer :check_delay

      t.timestamps
    end
  end
end
