class AddSocialLinksToFactories < ActiveRecord::Migration[8.1]
  def change
    add_column :factories, :facebook_url, :string
    add_column :factories, :instagram_url, :string
    add_column :factories, :viber_url, :string
    add_column :factories, :whatsapp_url, :string
  end
end
