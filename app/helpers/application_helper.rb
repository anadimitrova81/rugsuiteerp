module ApplicationHelper
  BG_WEEKDAYS = %w[неделя понеделник вторник сряда четвъртък петък събота].freeze
  BG_MONTHS = %w[януари февруари март април май юни юли август септември октомври ноември декември].freeze

  def bg_weekday(date)
    BG_WEEKDAYS[date.wday]&.capitalize
  end

  def bg_long_date(date)
    "#{date.day} #{BG_MONTHS[date.month - 1]} #{date.year}"
  end

  def bg_short_date(date)
    "#{date.day} #{BG_MONTHS[date.month - 1]}"
  end

  def bg_relative_day(date)
    today = Date.current
    days = (date.to_date - today).to_i
    case days
    when 0 then "Днес"
    when 1 then "Утре"
    when 2..6 then bg_weekday(date)
    when -1 then "Вчера"
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
    ["pickup_confirmed", "picked_up"] => "items",
    ["picked_up", "in_progress"]      => "weight",
  }.freeze

  def pickup_label(request)
    request.status.in?(%w[pending pickup_confirmed]) ? "Вземане" : "Взета"
  end

  def next_status_for(request)
    return nil unless current_admin
    ROLE_TRANSITIONS.dig(current_admin.role, request.status)
  end

  def transition_fields_for(request, next_status)
    TRANSITION_FIELDS[[request.status, next_status]]
  end

  ROLE_DESCRIPTIONS = {
    "admin" => "Пълен достъп — управлява поръчките и членовете на екипа.",
    "courier" => "Потвърждава вземането и връщането при доставка.",
    "operator" => "Изпълнява пранета в процес на обработка.",
    "coordinator" => "Триажира новите заявки и подготвя за връщане.",
  }.freeze

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
  # through every stop as a waypoint, back to the factory. Up to ~10 waypoints;
  # older Maps clients silently truncate beyond that.
  def google_maps_directions_url(addresses)
    return nil if addresses.blank?

    formatted = addresses.compact_blank.map { |a| a.to_s.tr("|", " ") }
    return nil if formatted.empty?

    depot = Routes::DailyRouteOptimizer::DEPOT_ADDRESS
    params = {
      api: 1,
      travelmode: "driving",
      origin: depot,
      destination: depot,
      waypoints: formatted.join("|"),
    }
    "https://www.google.com/maps/dir/?#{params.to_query}"
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

  COORDINATES_REGEX = /\A-?\d+\.\d+,-?\d+\.\d+\z/

  def waze_url(target)
    if target.to_s.match?(COORDINATES_REGEX)
      "https://waze.com/ul?ll=#{target}&navigate=yes"
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
    [request.address, request.city].compact_blank.join(", ")
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
    [m[1][0..1], m[1][2..3], m[1][4..5]].map { |c| c.to_i(16) }.join(", ")
  end

  def format_minutes_bg(total_minutes)
    return "0 мин" if total_minutes.to_i.zero?

    h = total_minutes.to_i / 60
    m = total_minutes.to_i % 60
    return "#{m} мин" if h.zero?
    return "#{h} ч" if m.zero?
    "#{h} ч #{m} мин"
  end
end
