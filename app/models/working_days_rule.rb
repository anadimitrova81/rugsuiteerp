# The weekdays clients can book a pickup on (ported from nexus-cleaning). One
# default rule (no dates) applies all year; a seasonal period (e.g. winter:
# Mon, Wed, Fri) overrides it between its dates, both inclusive. Admins edit
# them from Admin → Working days; staff can still schedule any day. A factory
# with no default rule books Monday–Friday.
class WorkingDaysRule < ApplicationRecord
  acts_as_tenant :factory

  # Ruby's / JavaScript's wday numbering (0 = Sunday), listed Monday first.
  WEEKDAYS = [ 1, 2, 3, 4, 5, 6, 0 ].freeze
  DEFAULT_WEEKDAYS = [ 1, 2, 3, 4, 5 ].freeze

  before_validation do
    self.weekdays = Array(weekdays).compact_blank.map(&:to_i).uniq.sort_by { |d| WEEKDAYS.index(d) || 99 }
  end

  validate :weekdays_chosen
  validate :period_dates, unless: :default?

  scope :periods, -> { where.not(starts_on: nil).order(:starts_on) }

  class << self
    def default_rule = find_by(starts_on: nil, ends_on: nil)

    def weekdays_on(date)
      rule = periods.find_by("starts_on <= :date AND ends_on >= :date", date: date) || default_rule
      rule&.weekdays.presence || DEFAULT_WEEKDAYS
    end

    def working_day?(date) = weekdays_on(date).include?(date.wday)

    # What the client date picker needs: the default days and every period
    # that hasn't ended yet, with ISO dates.
    def calendar
      {
        default: default_rule&.weekdays.presence || DEFAULT_WEEKDAYS,
        periods: periods.where(ends_on: Date.current..).map do |rule|
          { from: rule.starts_on.iso8601, to: rule.ends_on.iso8601, days: rule.weekdays }
        end,
      }
    end

    def short_name(wday) = I18n.t("date.abbr_day_names")[wday]
    def long_name(wday) = I18n.t("date.day_names")[wday]

    def long_label(weekdays)
      word = " #{I18n.t('admin.working_days.and')} "
      weekdays.map { |d| long_name(d) }.to_sentence(words_connector: ", ", two_words_connector: word, last_word_connector: word)
    end
  end

  def default? = starts_on.nil? && ends_on.nil?
  def past? = !default? && ends_on < Date.current
  def current? = !default? && (starts_on..ends_on).cover?(Date.current)

  def short_label = weekdays.map { |d| self.class.short_name(d) }.join(", ")
  def long_label = self.class.long_label(weekdays)

  private

  def weekdays_chosen
    if weekdays.empty?
      errors.add(:base, I18n.t("admin.working_days.errors.no_days"))
    elsif (weekdays - WEEKDAYS).any?
      errors.add(:base, I18n.t("admin.working_days.errors.invalid_day"))
    end
  end

  def period_dates
    if starts_on.nil? || ends_on.nil?
      errors.add(:base, I18n.t("admin.working_days.errors.dates_required"))
    elsif ends_on < starts_on
      errors.add(:base, I18n.t("admin.working_days.errors.end_before_start"))
    elsif self.class.periods.where.not(id: id).where("starts_on <= ? AND ends_on >= ?", ends_on, starts_on).exists?
      errors.add(:base, I18n.t("admin.working_days.errors.overlap"))
    end
  end
end
