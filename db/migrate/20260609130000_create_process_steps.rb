class CreateProcessSteps < ActiveRecord::Migration[8.1]
  def change
    create_table :process_steps do |t|
      t.references :factory, null: false, foreign_key: true
      t.integer :position, null: false, default: 0
      t.string :title, null: false
      t.text :body

      t.timestamps
    end

    add_index :process_steps, [:factory_id, :position]
  end
end
