module TracksPublicVisits
  extend ActiveSupport::Concern

  BOT_USER_AGENT = /bot|crawler|spider|crawling|slurp|facebookexternalhit|whatsapp|telegrambot|preview/i

  included do
    after_action :record_public_visit
  end

  private

  def record_public_visit
    return unless request.get?
    return unless response.successful?
    return if admin_logged_in?
    return if request.user_agent.to_s.match?(BOT_USER_AGENT)

    PageVisit.create!(
      route_key: "#{controller_name}##{action_name}",
      path: request.path.first(500),
      referrer: request.referer&.first(500),
      user_agent: request.user_agent&.first(500),
    )
  rescue StandardError => e
    Rails.logger.warn("[page_visit] failed to record: #{e.class} #{e.message}")
  end
end
