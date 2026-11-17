# A deactivated staff member keeps their history (orders they picked up or
# delivered still point at them) but can't log in and drops out of the
# route planner.
class AddActiveToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :active, :boolean, null: false, default: true
  end
end
