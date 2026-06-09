class AddPaidByCardToRequests < ActiveRecord::Migration[8.1]
  def change
    add_column :requests, :paid_by_card, :boolean, default: false, null: false
  end
end
