module Sms
  # Renders the single-segment Bulgarian SMS body for the in_progress price
  # quote. The prefix varies by order type so the customer immediately sees
  # what the message is about:
  #   - weight-based: "Пране на килими:"
  #   - items-based:  "Пране на завивки:"
  # The URL is bare (no https://) to fit one segment in Cyrillic encoding;
  # modern phones auto-link it. The URL points to /r/:customer_id which 302s
  # to /status where the full breakdown lives.
  module PriceQuoteMessage
    DETAILS_URL_HOST = "nexus-cleaning.com".freeze

    def self.build(request)
      "#{prefix(request)} #{summary_line(request)}. Виж: #{details_url(request)}"
    end

    def self.prefix(request)
      request.weight.present? ? "Пране на килими:" : "Пране на завивки:"
    end

    def self.summary_line(request)
      "#{metric(request)}, #{format_number(request.amount.to_f.round(2))} €"
    end

    def self.metric(request)
      if request.weight.present?
        "#{format_number(request.weight, strip_zeros: true)} кг"
      else
        "#{request.number_of_items} бр."
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
