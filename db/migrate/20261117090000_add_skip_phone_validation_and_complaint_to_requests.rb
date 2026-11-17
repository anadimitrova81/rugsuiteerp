# Ported from nexus-cleaning:
# - skip_phone_validation: admins can switch the phone format check off for the
#   occasional foreign or non-standard number. Persisted so later courier /
#   operator saves on the same order don't re-trip the check.
# - complaint: an order that came back as a customer complaint; re-washed free.
class AddSkipPhoneValidationAndComplaintToRequests < ActiveRecord::Migration[8.1]
  def change
    add_column :requests, :skip_phone_validation, :boolean, default: false, null: false
    add_column :requests, :complaint, :boolean, default: false, null: false
  end
end
