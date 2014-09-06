class CreateAlerts < ActiveRecord::Migration
  def change
    create_table :alerts do |t|
      t.references :metric
      t.text :recipients

      t.timestamps
    end
    add_index :alerts, :metric_id
  end
end
