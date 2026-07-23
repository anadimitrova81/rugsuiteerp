module SeoHelper
  # Fallback meta description for pages that don't set their own via
  # content_for(:description). Built from the tenant's own name and tagline so
  # each factory gets a relevant snippet; kept short for search results.
  def page_description
    return content_for(:description).to_s.squish if content_for?(:description)

    [ current_factory.name, current_factory.hero_tagline ].compact_blank.join(" — ").squish
  end

  # Self-referencing canonical URL without query string, so duplicate
  # parameterised URLs collapse to one indexable address.
  def canonical_url
    request.base_url + request.path
  end

  # The only pages we want search engines to index are the tenant's public
  # marketing pages. Every other response (order flow, status, admin) is
  # transactional or private and carries a noindex directive so it never
  # competes for the index.
  INDEXABLE_ACTIONS = {
    "pages" => %w[home faq contacts terms privacy],
  }.freeze

  def indexable_page?
    INDEXABLE_ACTIONS[params[:controller]]&.include?(params[:action]) || false
  end
end
