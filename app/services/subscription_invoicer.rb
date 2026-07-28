# Issues subscription invoices for a factory (tenant). Two entry points:
#
#   * `issue_for_plan_change(factory)` — called when an admin switches to a
#     billable plan. Starts a fresh billing period from today.
#   * `issue_due(factory)` — called by the monthly recurring job. Creates the
#     next period's invoice once the current one has elapsed. Idempotent: it
#     only ever creates the single invoice that is due, so running it daily is
#     safe.
#
# Free plans are never billed. All writes assume the factory's tenant scope.
class SubscriptionInvoicer
  class << self
    def issue_for_plan_change(factory)
      return unless factory.billable_plan?

      start = today(factory)
      create_invoice(factory, period_start: start)
    end

    # Creates at most one invoice — the next period after the latest existing
    # one — and only when that period has actually begun. Returns the invoice
    # it created, or nil.
    def issue_due(factory)
      return unless factory.billable_plan?

      ActsAsTenant.with_tenant(factory) do
        last = factory.invoices.order(period_end: :desc).first
        # No history yet: the plan-change path seeds the first invoice, so we
        # don't retroactively create one here.
        return nil if last.nil?

        next_start = last.period_end + 1.day
        return nil if next_start > today(factory)

        create_invoice(factory, period_start: next_start)
      end
    end

    private

    def create_invoice(factory, period_start:)
      ActsAsTenant.with_tenant(factory) do
        factory.invoices.create!(
          plan:         factory.plan,
          amount_cents: factory.plan_price_cents,
          currency:     Factory::BILLING_CURRENCY,
          period_start: period_start,
          period_end:   period_start.next_month - 1.day,
          issued_on:    period_start,
          status:       "issued",
          # Snapshot the recipient (получател) at issue time so later edits to
          # the tenant's billing details never rewrite past invoices.
          recipient_name:         factory.billing_company_name.presence || factory.name,
          recipient_address:      factory.billing_address,
          recipient_eik:          factory.billing_eik,
          recipient_vat_number:   factory.billing_vat_number,
          recipient_mol:          factory.billing_mol,
          recipient_country_code: factory.country_code,
          locale:                 factory.default_locale,
          vat_rate:             0,
          vat_grounds:          Invoice::VAT_GROUNDS,
          discount_percent:     0,
        )
      end
    end

    def today(factory)
      Time.current.in_time_zone(factory.time_zone).to_date
    end
  end
end
