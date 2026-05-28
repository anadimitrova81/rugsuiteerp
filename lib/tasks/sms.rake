namespace :sms do
  # Renders the price-quote body for a given request, prints it to stdout,
  # then sends it for real via smsapi.bg. Bypasses Sms::Sender's LogBackend
  # gating so this works from dev without SMS_LIVE=1. No Notification record
  # is created — purely for verifying the dispatch.
  #
  # ⚠ Each call costs ~0.05 BGN. Use your own number.
  desc "Render and send the price-quote SMS for a request (live, echoes body)"
  task :test_price_quote, [:to, :request_id] => :environment do |_t, args|
    raise ArgumentError, "Usage: rails 'sms:test_price_quote[+359888...,REQUEST_ID]'" if args[:to].blank?

    request =
      if args[:request_id].present?
        Request.find(args[:request_id])
      else
        Request.where(status: "in_progress").where("weight IS NOT NULL OR items_only").first
      end
    raise "No eligible request found." unless request

    body = Sms::PriceQuoteMessage.build(request)
    to = Sms::PhoneNumber.normalize(args[:to])

    token = Rails.application.credentials.dig(:smsapi_bg, :token) || ENV["SMSAPI_BG_TOKEN"]
    abort "smsapi.bg token missing. Add it under credentials:smsapi_bg:token or set SMSAPI_BG_TOKEN." if token.blank?
    sender = Rails.application.credentials.dig(:smsapi_bg, :sender) || ENV["SMSAPI_BG_SENDER"]

    puts "─────────────────────────────────────────────────────────"
    puts "→ LIVE smsapi.bg send"
    puts "  to:      #{to} (input: #{args[:to]})"
    puts "  sender:  #{sender || '(default)'}"
    puts "  request: ##{request.customer_id} (id=#{request.id})"
    puts "  length:  #{body.length} chars · #{body.length <= 70 ? 1 : 2} segment"
    puts "─────────────────────────────────────────────────────────"
    puts body
    puts "─────────────────────────────────────────────────────────"

    Sms::SmsapiBgBackend.new(token: token, sender_name: sender).deliver(to: to, body: body)
    puts "✓ sent"
  end
end
