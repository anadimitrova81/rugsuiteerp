class AddStatusTokenToRequests < ActiveRecord::Migration[8.1]
  # Adds a random, unguessable per-request token used in the SMS short link
  # (/r/:token). Replaces the previous use of the sequential customer_id in
  # public URLs — anyone could iterate that and enumerate other customers'
  # name/phone/address.
  def up
    add_column :requests, :status_token, :string, if_not_exists: true

    Request.reset_column_information
    Request.where(status_token: nil).find_each do |req|
      loop do
        candidate = SecureRandom.hex(4)
        next if Request.exists?(status_token: candidate)
        req.update_column(:status_token, candidate)
        break
      end
    end

    change_column_null :requests, :status_token, false
    add_index :requests, :status_token, unique: true, if_not_exists: true
  end

  def down
    remove_index :requests, :status_token, if_exists: true
    remove_column :requests, :status_token, if_exists: true
  end
end
