class RenamePlansToFreeStarterPro < ActiveRecord::Migration[8.1]
  def up
    # trial is replaced by a permanent free tier; enterprise is dropped (fold
    # any into pro, the new top tier).
    execute("UPDATE factories SET plan = 'free' WHERE plan = 'trial'")
    execute("UPDATE factories SET plan = 'pro' WHERE plan = 'enterprise'")
    change_column_default :factories, :plan, from: "trial", to: "free"
  end

  def down
    change_column_default :factories, :plan, from: "free", to: "trial"
    execute("UPDATE factories SET plan = 'trial' WHERE plan = 'free'")
  end
end
