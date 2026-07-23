module Sms
  # Renders the single-segment price-quote SMS body for the in_progress price
  # quote (localised via `sms.price_quote.*`). The prefix varies by order type
  # so the customer immediately sees what the message is about (carpet wash vs
  # duvet/item wash).
  # The URL is bare (no https://) to fit one segment in Cyrillic encoding;
  # modern phones auto-link it. The URL points to /r/:customer_id which 302s
  # to /status where the full breakdown lives.
  module PriceQuoteMessage
    DETAILS_URL_HOST = "nexus-cleaning.com".freeze

    def self.build(request)
      I18n.t("sms.price_quote.body",
             prefix: prefix(request),
             summary: summary_line(request),
             url: details_url(request))
    end

    def self.prefix(request)
      I18n.t(request.weight.present? ? "sms.price_quote.prefix_weight" : "sms.price_quote.prefix_items")
    end

    def self.summary_line(request)
      "#{metric(request)}, #{format_number(request.amount.to_f.round(2))} €"
    end

    def self.metric(request)
      if request.weight.present?
        "#{format_number(request.weight, strip_zeros: true)} #{I18n.t('units.kg')}"
      else
        "#{request.number_of_items} #{I18n.t('sms.price_quote.items_unit')}"
      end
    end

    def self.details_url(request)
      "#{DETAILS_URL_HOST}/r/#{request.status_token}"
    end

    def self.format_number(value, strip_zeros: false)
      ActiveSupport::NumberHelper.number_to_rounded(
        value,
        precision: 2,
        strip_insignificant_zeros: strip_zeros,
      )
    end
  end
end
