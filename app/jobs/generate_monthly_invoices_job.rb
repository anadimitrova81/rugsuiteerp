# Creates the next monthly invoice for every factory on a billable plan whose
# current billing period has elapsed. Scheduled daily (see config/recurring.yml)
# and idempotent — SubscriptionInvoicer.issue_due creates at most the single
# invoice that's due, so a factory gets exactly one invoice per period no matter
# how often this runs.
#
# Factory is the tenant record itself (not tenant-scoped), so we can iterate it
# directly; SubscriptionInvoicer wraps the per-tenant writes in the right scope.
class GenerateMonthlyInvoicesJob < ApplicationJob
  queue_as :default

  def perform
    Factory.where(plan: billable_plans).find_each do |factory|
      SubscriptionInvoicer.issue_due(factory)
    rescue => e
      # Don't let one tenant's failure abort the whole run.
      Rails.logger.error("[invoices] issue_due failed for factory=#{factory.id}: #{e.class} #{e.message}")
    end
  end

  private

  def billable_plans
    Factory::PLAN_PRICES.select { |_plan, cents| cents.positive? }.keys
  end
end
