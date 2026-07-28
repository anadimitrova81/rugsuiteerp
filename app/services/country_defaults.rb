module CountryDefaults
  # Defaults applied when provisioning a new Factory. Keep the list short for
  # MVP — the factory can change everything via the (future) settings page.
  # Each entry: timezone, currency, default_locale, phone_country.
  DEFAULTS = {
    "BG" => { timezone: "Europe/Sofia",      currency: "BGN", default_locale: "bg", phone_country: "BG" },
    "RO" => { timezone: "Europe/Bucharest",  currency: "RON", default_locale: "en", phone_country: "RO" },
    "GR" => { timezone: "Europe/Athens",     currency: "EUR", default_locale: "en", phone_country: "GR" },
    "DE" => { timezone: "Europe/Berlin",     currency: "EUR", default_locale: "en", phone_country: "DE" },
    "FR" => { timezone: "Europe/Paris",      currency: "EUR", default_locale: "fr", phone_country: "FR" },
    "TR" => { timezone: "Europe/Istanbul",   currency: "TRY", default_locale: "tr", phone_country: "TR" },
    "MK" => { timezone: "Europe/Skopje",     currency: "MKD", default_locale: "mk", phone_country: "MK" },
    "RS" => { timezone: "Europe/Belgrade",   currency: "RSD", default_locale: "sr", phone_country: "RS" },
    "IT" => { timezone: "Europe/Rome",       currency: "EUR", default_locale: "en", phone_country: "IT" },
    "ES" => { timezone: "Europe/Madrid",     currency: "EUR", default_locale: "en", phone_country: "ES" },
    "PL" => { timezone: "Europe/Warsaw",     currency: "PLN", default_locale: "en", phone_country: "PL" },
    "GB" => { timezone: "Europe/London",     currency: "GBP", default_locale: "en", phone_country: "GB" },
    "IE" => { timezone: "Europe/Dublin",     currency: "EUR", default_locale: "en", phone_country: "IE" },
    "NL" => { timezone: "Europe/Amsterdam",  currency: "EUR", default_locale: "en", phone_country: "NL" },
    "AT" => { timezone: "Europe/Vienna",     currency: "EUR", default_locale: "en", phone_country: "AT" },
    "US" => { timezone: "America/New_York",  currency: "USD", default_locale: "en", phone_country: "US" },
  }.freeze

  # Display labels for the signup form. Ordered by likelihood of carpet-wash
  # demand for now; tweak when usage data tells us otherwise.
  COUNTRY_LABELS = {
    "BG" => "Bulgaria",     "RO" => "Romania",     "GR" => "Greece",
    "DE" => "Germany",      "FR" => "France",      "TR" => "Turkey",
    "MK" => "North Macedonia", "RS" => "Serbia",   "IT" => "Italy",
    "ES" => "Spain",        "PL" => "Poland",      "GB" => "United Kingdom",
    "IE" => "Ireland",      "NL" => "Netherlands", "AT" => "Austria",
    "US" => "United States",
  }.freeze

  module_function

  def for(country_code)
    DEFAULTS[country_code.to_s.upcase]
  end

  def supported?(country_code)
    DEFAULTS.key?(country_code.to_s.upcase)
  end

  # Returns [[label, code], ...] suitable for a Rails select helper.
  def select_options
    COUNTRY_LABELS.map { |code, label| [label, code] }
  end
end
