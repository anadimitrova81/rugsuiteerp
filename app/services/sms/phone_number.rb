module Sms
  # Normalizes Bulgarian mobile numbers to E.164 (+359XXXXXXXXX) before they
  # hit smsapi.bg, which only accepts that format. The Request model still
  # allows either form on input (Request::BULGARIAN_PHONE_REGEX); this
  # converts to the canonical shape on the way out.
  module PhoneNumber
    # Accepts:
    #   "0888123456"        → "+359888123456"
    #   "+359888123456"     → "+359888123456"
    #   "359888123456"      → "+359888123456"
    #   "0888 123 456"      → "+359888123456"
    #   "+359 (888) 12-3456" → "+359888123456"
    #
    # Returns the original string if it doesn't look like a Bulgarian mobile,
    # so the backend can surface a clearer error than a silent corruption.
    def self.normalize(raw)
      return raw if raw.blank?

      digits = raw.to_s.gsub(/[^\d]/, "")
      digits = digits.sub(/\A359/, "")
      digits = digits.sub(/\A0/, "")

      return raw unless digits.match?(/\A(87|88|89|98|99)\d{7}\z/)

      "+359#{digits}"
    end

    # Returns every common Bulgarian format the same phone could be stored
    # under, given a free-form input. Used to make /status lookups
    # format-agnostic — customer searches "+359888…" but the DB might hold
    # "0888…" or vice-versa. Falls back to [raw] if the input doesn't
    # parse as a Bulgarian mobile.
    def self.variants(raw)
      normalized = normalize(raw)
      return [raw].compact if normalized.blank? || !normalized.to_s.start_with?("+359")

      bare = normalized.delete_prefix("+359")
      ["+359#{bare}", "359#{bare}", "0#{bare}"]
    end
  end
end
