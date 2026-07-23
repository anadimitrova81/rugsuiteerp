module ApplicationHelper
  # Language switcher (client-facing pages). Short codes drive the toggle,
  # native names label it for screen readers, and `locale_switch_url` re-renders
  # the current page in the chosen locale — the controller validates the value
  # and remembers it for the session.
  LOCALE_SHORT_LABELS = { en: "EN", bg: "БГ" }.freeze
  LOCALE_NATIVE_NAMES = { en: "English", bg: "Български" }.freeze

  def locale_short_label(loc)
    LOCALE_SHORT_LABELS[loc.to_sym] || loc.to_s.upcase
  end

  def locale_native_name(loc)
    LOCALE_NATIVE_NAMES[loc.to_sym] || loc.to_s
  end

  def locale_switch_url(loc)
    url_for(request.params.merge(locale: loc, only_path: true))
  end

  # Dates render per-locale through Rails' I18n localisation: month/day names
  # and the `long`/`short` format strings live under `date.*` in each locale
  # file, so these helpers return Bulgarian under :bg and English under :en
  # without callers having to care. (Method names keep the `bg_` prefix for
  # historical call-site compatibility.)
  def bg_weekday(date)
    return nil if date.nil?
    I18n.l(date.to_date, format: "%A").capitalize
  end

  def bg_long_date(date)
    return nil if date.nil?
    I18n.l(date.to_date, format: :long)
  end

  # Social platforms shown in the home footer. :mode picks how the glyph is
  # drawn (brand logos are filled; the others are stroked line icons). Colors
  # are applied via the .home-social-<key> CSS classes.
  SOCIAL_PLATFORMS = {
    "viber" => { mode: :stroke, svg: '<path d="M21 11.5a8.38 8.38 0 0 1-.9 3.8 8.5 8.5 0 0 1-7.6 4.7 8.38 8.38 0 0 1-3.8-.9L3 21l1.9-5.7a8.38 8.38 0 0 1-.9-3.8 8.5 8.5 0 0 1 4.7-7.6 8.38 8.38 0 0 1 3.8-.9h.5a8.48 8.48 0 0 1 8 8v.5z"/>' },
    "whatsapp" => { mode: :fill, svg: '<path d="M17.47 14.38c-.3-.15-1.77-.87-2.04-.97-.27-.1-.47-.15-.67.15-.2.3-.77.97-.94 1.17-.17.2-.35.22-.65.07-.3-.15-1.26-.46-2.4-1.48-.89-.79-1.49-1.77-1.66-2.07-.17-.3-.02-.46.13-.61.13-.13.3-.35.45-.52.15-.17.2-.3.3-.5.1-.2.05-.37-.03-.52-.07-.15-.67-1.62-.92-2.22-.24-.58-.49-.5-.67-.51-.17-.01-.37-.01-.57-.01-.2 0-.52.07-.79.37-.27.3-1.04 1.01-1.04 2.47s1.06 2.87 1.21 3.07c.15.2 2.08 3.18 5.05 4.46.7.3 1.26.48 1.69.62.71.22 1.36.19 1.87.12.57-.08 1.77-.72 2.02-1.42.25-.7.25-1.3.17-1.42-.07-.13-.27-.2-.57-.35zM12.04 2C6.58 2 2.13 6.45 2.13 11.91c0 1.75.46 3.45 1.32 4.95L2 22l5.25-1.38a9.9 9.9 0 0 0 4.79 1.22h.01c5.46 0 9.91-4.45 9.91-9.91 0-2.65-1.03-5.14-2.9-7.01A9.83 9.83 0 0 0 12.04 2z"/>' },
    "facebook" => { mode: :fill, svg: '<path d="M22 12a10 10 0 1 0-11.56 9.88v-6.99H7.9V12h2.54V9.8c0-2.51 1.49-3.89 3.77-3.89 1.09 0 2.24.2 2.24.2v2.46h-1.26c-1.24 0-1.63.77-1.63 1.56V12h2.77l-.44 2.89h-2.33v6.99A10 10 0 0 0 22 12z"/>' },
    "instagram" => { mode: :stroke, svg: '<rect x="2" y="2" width="20" height="20" rx="5" ry="5"/><path d="M16 11.37A4 4 0 1 1 12.63 8 4 4 0 0 1 16 11.37z"/><line x1="17.5" y1="6.5" x2="17.51" y2="6.5"/>' },
  }.freeze

  # Ordered platform => url map for a factory, skipping ones that aren't set.
  def factory_social_links(factory)
    {
      "viber" => factory.viber_link,
      "whatsapp" => factory.whatsapp_link,
      "facebook" => factory.facebook_link,
      "instagram" => factory.instagram_link,
    }.select { |_key, url| url.present? }
  end

  def social_icon(platform)
    config = SOCIAL_PLATFORMS[platform]
    return "" unless config

    common = { xmlns: "http://www.w3.org/2000/svg", viewBox: "0 0 24 24", width: 18, height: 18, "aria-hidden": true }
    attrs =
      if config[:mode] == :fill
        common.merge(fill: "currentColor")
      else
        common.merge(fill: "none", stroke: "currentColor", "stroke-width": 2, "stroke-linecap": "round", "stroke-linejoin": "round")
      end
    content_tag(:svg, config[:svg].html_safe, attrs)
  end

  # The "How it works" slider is a pure-CSS carousel whose active-state rules
  # (track position, slide reveal, dot fill, progress bar) are keyed to each
  # step's index. Because the step count is configurable per factory, those
  # index-specific rules can't live statically in application.css — we emit
  # them here for the actual count. The structural styling (sizes, colours,
  # transitions) stays in application.css; this only sets per-index state.
  def process_slider_state_css(count)
    return "".html_safe if count.to_i < 1

    track = ".process-slides-viewport .process-slides"
    dot_glow = "background: var(--color-primary); color: #fff; border-color: var(--color-primary);"
    rules = []

    (1..count).each do |i|
      on = "#step-radio-#{i}:checked ~"
      slide = "#{track} .process-slide:nth-child(#{i})"

      rules << "#{on} #{track} { transform: translateX(-#{(i - 1) * 100}%); }"
      rules << "#{on} #{slide} .process-slide-image img { transform: scale(1.12); }"
      rules << "#{on} #{slide} .process-slide-body > * { opacity: 1; transform: translateY(0); }"
      rules << "#{on} #{slide} .process-slide-body .process-slide-num { transition-delay: 0.15s; }"
      rules << "#{on} #{slide} .process-slide-body h3 { transition-delay: 0.22s; }"
      rules << "#{on} #{slide} .process-slide-body p { transition-delay: 0.3s; }"
      rules << %(#{on} .process-dots label[for="step-radio-#{i}"] { #{dot_glow} transform: scale(1.15); box-shadow: 0 0 0 6px rgba(var(--color-primary-rgb), 0.18), 0 8px 20px rgba(var(--color-primary-rgb), 0.3); })

      if i > 1
        visited = (1...i).map { |k| %(#{on} .process-dots label[for="step-radio-#{k}"]) }.join(",")
        rules << "#{visited} { #{dot_glow} }"
      end
    end

    [ 38, 32 ].each do |dot_px|
      width_rules = (1..count).map do |i|
        frac = count > 1 ? ((i - 1).to_f / (count - 1)).round(4) : 0
        "#step-radio-#{i}:checked ~ .process-dots::after { width: calc((100% - #{dot_px}px) * #{frac}); }"
      end
      rules << if dot_px == 32
        "@media (max-width: 760px) {\n#{width_rules.join("\n")}\n}"
      else
        width_rules.join("\n")
      end
    end

    rules.join("\n").html_safe
  end

  def bg_short_date(date)
    return nil if date.nil?
    I18n.l(date.to_date, format: :short)
  end

  # Locale-aware long/short date. Kept as thin aliases now that the underlying
  # helpers localise themselves via I18n. Use for user-facing dates in admin
  # pages.
  def long_date(date)
    bg_long_date(date)
  end

  def short_date(date)
    bg_short_date(date)
  end

  def bg_relative_day(date)
    relative_day(date)
  end

  # Locale-aware relative day label. Bulgarian uses BG weekday names; other
  # locales fall back to localized weekday via `%A` strftime.
  def relative_day(date)
    today = Date.current
    days = (date.to_date - today).to_i
    case days
    when 0 then I18n.t("admin.relative_day.today")
    when 1 then I18n.t("admin.relative_day.tomorrow")
    when 2..6
      bg_weekday(date)
    when -1 then I18n.t("admin.relative_day.yesterday")
    end
  end

  ROLE_TRANSITIONS = {
    "courier" => {
      "pickup_confirmed" => "picked_up",
      "delivery_confirmed" => "delivered",
    },
    "operator" => {
      "picked_up" => "in_progress",
      "in_progress" => "ready_for_delivery",
    },
    "coordinator" => {
      "pending" => "pickup_confirmed",
      "ready_for_delivery" => "delivery_confirmed",
    },
  }.freeze

  TRANSITION_FIELDS = {
    [ "pickup_confirmed", "picked_up" ] => "items",
    [ "picked_up", "in_progress" ]      => "weight",
  }.freeze

  def pickup_label(request)
    key = request.status.in?(%w[pending pickup_confirmed]) ? "admin.requests.cols.pickup" : "admin.request_status.picked_up"
    I18n.t(key)
  end

  def next_status_for(request)
    return nil unless current_admin
    ROLE_TRANSITIONS.dig(current_admin.role, request.status)
  end

  def transition_fields_for(request, next_status)
    TRANSITION_FIELDS[[ request.status, next_status ]]
  end

  # ROLE_DESCRIPTIONS moved to I18n (admin.user.role_descriptions.*) and
  # accessed via User.role_description(role).

  ROLE_ICON_PATHS = {
    "admin" => '<path d="M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z"/><path d="m9 12 2 2 4-4"/>',
    "courier" => '<path d="M14 18V6a2 2 0 0 0-2-2H4a2 2 0 0 0-2 2v11a1 1 0 0 0 1 1h2"/><path d="M15 18H9"/><path d="M19 18h2a1 1 0 0 0 1-1v-3.65a1 1 0 0 0-.22-.624l-3.48-4.35A1 1 0 0 0 17.52 8H14"/><circle cx="17" cy="18" r="2"/><circle cx="7" cy="18" r="2"/>',
    "operator" => '<path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z"/>',
    "coordinator" => '<rect width="8" height="4" x="8" y="2" rx="1" ry="1"/><path d="M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2"/><path d="M12 11h4"/><path d="M12 16h4"/><path d="M8 11h.01"/><path d="M8 16h.01"/>',
  }.freeze

  def role_icon(role, size: 16)
    path = ROLE_ICON_PATHS[role.to_s]
    return "" unless path

    tag.svg(path.html_safe,
            xmlns: "http://www.w3.org/2000/svg",
            width: size, height: size, viewBox: "0 0 24 24",
            fill: "none", stroke: "currentColor", "stroke-width": 2,
            "stroke-linecap": "round", "stroke-linejoin": "round")
  end

  # Builds a Google Maps directions URL routing the courier from the factory,
  # through every stop, back to the factory.
  #
  # Uses the path-based /maps/dir/ format (depot/stop1/stop2/.../depot) rather
  # than dir/?api=1. The api=1 form caps the `waypoints` parameter at 9
  # intermediate stops and silently drops the rest; the path-based form carries
  # every assigned stop as its own path segment.
  def google_maps_directions_url(addresses)
    return nil if addresses.blank?

    formatted = addresses.compact_blank.map(&:to_s)
    return nil if formatted.empty?

    # Use the depot's coordinates, not DEPOT_ADDRESS — the address string
    # ("с. Труд, …") fails Google's geocoder ("Address not found"), which would
    # break the start/end of the route. Coordinates always resolve.
    depot = Routes::DailyRouteOptimizer::DEPOT.join(",")
    segments = [ depot, *formatted, depot ].map { |a| CGI.escape(a) }
    "https://www.google.com/maps/dir/#{segments.join('/')}?travelmode=driving"
  end

  # Builds a Google Maps directions URL from the user's current location to
  # the given address. Omitting `origin` makes Maps prompt for/use the
  # device's current location — what couriers want when navigating to a
  # single stop, as opposed to running the whole depot-anchored day route.
  def google_maps_navigate_url(address)
    return nil if address.blank?

    formatted = address.to_s.tr("|", " ")
    params = {
      api: 1,
      travelmode: "driving",
      destination: formatted,
    }
    "https://www.google.com/maps/dir/?#{params.to_query}"
  end

  # "lat,lng", tolerant of whitespace around the comma and ends — coordinator
  # pins are often pasted as "42.1, 24.7" or with a stray leading space, and a
  # pin must still be recognised as coordinates (it's authoritative for routing).
  COORDINATES_REGEX = /\A\s*-?\d+\.\d+\s*,\s*-?\d+\.\d+\s*\z/

  def waze_url(target)
    if target.to_s.match?(COORDINATES_REGEX)
      "https://waze.com/ul?ll=#{target.to_s.gsub(/\s+/, "")}&navigate=yes"
    else
      "https://waze.com/ul?q=#{CGI.escape(target.to_s)}&navigate=yes"
    end
  end

  # Drops a pin on the address (for verification), as opposed to opening
  # turn-by-turn directions like google_maps_directions_url does.
  # Coordinates are passed straight through; Google Maps recognises them.
  def google_maps_search_url(target)
    "https://www.google.com/maps/search/?api=1&query=#{CGI.escape(target.to_s)}"
  end

  def request_full_address(request)
    return request.verified_address if request.verified_address.present?
    [ request.address, request.city ].compact_blank.join(", ")
  end

  # Masks all but the last 3 digits of a phone number for public display
  # (e.g. on the customer status card). "0888123456" → "xxx xxx x 456"
  def mask_phone(phone)
    digits = phone.to_s.gsub(/\D/, "")
    return "—" if digits.length < 3
    "xxx xxx xxx #{digits[-3..]}"
  end

  # "#0f3f7e" → "15, 63, 126". Used to override --color-*-rgb CSS variables
  # for the per-tenant brand-color injection in layouts/application.html.erb.
  # Returns nil for blank or malformed input so the caller can fall back to
  # the default token.
  def hex_to_rgb_triplet(hex)
    return nil if hex.blank?
    m = hex.to_s.match(/\A#([0-9A-Fa-f]{6})\z/)
    return nil unless m
    [ m[1][0..1], m[1][2..3], m[1][4..5] ].map { |c| c.to_i(16) }.join(", ")
  end

  def format_minutes_bg(total_minutes)
    return "0 #{I18n.t('datetime.minutes_short')}" if total_minutes.to_i.zero?

    h = total_minutes.to_i / 60
    m = total_minutes.to_i % 60
    min = I18n.t("datetime.minutes_short")
    hr = I18n.t("datetime.hours_short")
    return "#{m} #{min}" if h.zero?
    return "#{h} #{hr}" if m.zero?
    "#{h} #{hr} #{m} #{min}"
  end
end
