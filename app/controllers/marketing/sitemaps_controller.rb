module Marketing
  # XML sitemap for the marketing site, with hreflang alternates for every
  # locale so search engines index the right language variant.
  class SitemapsController < BaseController
    PATHS = %w[/ /signup].freeze

    def show
      render plain: build(request.base_url), content_type: "application/xml"
    end

    private

    def build(base)
      xml = +%(<?xml version="1.0" encoding="UTF-8"?>\n)
      xml << %(<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">\n)
      PATHS.each do |path|
        loc = base + path
        xml << "  <url>\n    <loc>#{loc}</loc>\n"
        I18n.available_locales.each do |l|
          href = l == I18n.default_locale ? loc : "#{loc}?locale=#{l}"
          xml << %(    <xhtml:link rel="alternate" hreflang="#{l}" href="#{href}"/>\n)
        end
        xml << %(    <xhtml:link rel="alternate" hreflang="x-default" href="#{loc}"/>\n)
        xml << "  </url>\n"
      end
      xml << "</urlset>\n"
      xml
    end
  end
end
