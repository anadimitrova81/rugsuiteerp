# The weekdays clients can book a pickup on, per factory: one default rule
# (no dates) plus seasonal periods that override it. A factory without a
# default rule falls back to Monday–Friday (the previous hardcoded rule).
class CreateWorkingDaysRules < ActiveRecord::Migration[8.1]
  def change
    create_table :working_days_rules do |t|
      t.references :factory, null: false, foreign_key: true
      t.date :starts_on
      t.date :ends_on
      t.integer :weekdays, array: true, null: false, default: []
      t.timestamps
    end
  end
end
