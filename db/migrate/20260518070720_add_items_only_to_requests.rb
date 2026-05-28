class AddItemsOnlyToRequests < ActiveRecord::Migration[8.1]
  def change
    # if_not_exists handles the historical drift: the column was already added
    # to some envs by an in-place edit of the original CreateRequests migration
    # (which never re-runs once recorded). Prod is the env that needs it.
    add_column :requests, :items_only, :boolean, default: false, null: false, if_not_exists: true
  end
end
