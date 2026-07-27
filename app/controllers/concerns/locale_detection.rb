# Best-guess locale for a first-time visitor who hasn't made an explicit choice.
# Shared by the tenant stack (ApplicationController) and the marketing site
# (Marketing::BaseController), which both inherit ActionController::Base.
#
# Signals, in order:
#   1. Accept-Language — the browser's own language preference (strongest: it
#      reflects what the person reads, not just where they are).
#   2. CF-IPCountry — the country Cloudflare resolves from the client IP, used
#      only when the header is absent or lists nothing we support.
#
# Returns nil when nothing matches, so callers fall through to
# I18n.default_locale. Never writes the session — auto-detection re-runs on each
# request until the visitor picks a language explicitly (?locale=).
module LocaleDetection
  extend ActiveSupport::Concern

  # ISO-3166-1 alpha-2 country → locale, for the languages we ship.
  COUNTRY_LOCALES = { "BG" => :bg }.freeze

  private

  def browser_preferred_locale
    locale_from_accept_language || locale_from_country
  end

  # Parse "bg-BG,bg;q=0.9,en-US;q=0.8,en;q=0.7" into primary subtags ordered by
  # descending q-weight, then return the first one we actually support.
  def locale_from_accept_language
    header = request.env["HTTP_ACCEPT_LANGUAGE"].presence
    return unless header

    ranked = header.split(",").filter_map do |part|
      tag, *params = part.strip.split(";")
      next if tag.blank?

      q    = params.find { |p| p.start_with?("q=") }&.slice(2..)&.to_f || 1.0
      lang = tag.split("-").first&.downcase&.to_sym
      [lang, q] if lang
    end

    ranked.sort_by { |(_lang, q)| -q }
          .map(&:first)
          .find { |l| I18n.available_locales.include?(l) }
  end

  def locale_from_country
    country = request.headers["CF-IPCountry"].presence
    return unless country

    locale = COUNTRY_LOCALES[country.upcase]
    locale if locale && I18n.available_locales.include?(locale)
  end
end
