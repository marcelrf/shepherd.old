class CreateMetrics < ActiveRecord::Migration
  def change
    create_table :metrics do |t|
      t.references :source
      t.string :name
      t.string :polarity
      t.string :kind

      t.timestamps
    end
  end
end
