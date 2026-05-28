class AddDeliveryNotesToRequests < ActiveRecord::Migration[8.1]
  def change
    add_column :requests, :delivery_notes, :text
  end
end
