class AddPlanToFactories < ActiveRecord::Migration[8.1]
  def change
    add_column :factories, :plan, :string, null: false, default: "trial"
    add_index  :factories, :plan
  end
end
