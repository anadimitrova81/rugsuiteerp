class Invoice < ApplicationRecord
  acts_as_tenant :factory

  STATUSES = %w[issued paid].freeze

  # Fixed BGN peg (лев is pegged to the euro). Used to show both currencies on
  # the фактура, as Bulgarian invoices require during the transition period.
  BGN_PER_EUR = BigDecimal("1.95583")

  # The issuer (доставчик) — the SaaS operator. Not VAT-registered, so invoices
  # carry 0% ДДС with the small-supplier ground.
  SUPPLIER = {
    name:    "Нексус ООД",
    address: "ул. Дякон Иларион 4 ет.4 ап.4\n4000 Пловдив\nБългария",
    eik:     "112641285",
    vat_number: nil,
    mol:     "Георги Димитров, Ана Димитрова",
  }.freeze
  VAT_GROUNDS = "чл.113 ал.9 от ЗДДС".freeze
  PAYMENT_METHOD = "по банков път".freeze

  validates :plan, presence: true
  validates :amount_cents, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :currency, presence: true
  validates :period_start, :period_end, :issued_on, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :chronological, -> { order(period_start: :desc, id: :desc) }

  after_create :assign_number

  def amount
    amount_cents / 100.0
  end

  # Net (base) amount in euros after any discount. With discount_percent = 0
  # this equals the gross amount.
  def net_amount
    (amount_cents * (100 - discount_percent) / 100).round / 100.0
  end

  def vat_amount
    (net_amount * vat_rate / 100.0).round(2)
  end

  # Total due in euros (net + VAT).
  def total_amount
    (net_amount + vat_amount).round(2)
  end

  def to_bgn(euros)
    (BigDecimal(euros.to_s) * BGN_PER_EUR).round(2)
  end

  def paid?
    status == "paid"
  end

  private

  def assign_number
    # 10-digit sequential number in the "5000000000" family, matching the
    # issuer's existing invoice numbering.
    update_column(:number, format("%010d", 5_000_000_000 + id))
  end
end
