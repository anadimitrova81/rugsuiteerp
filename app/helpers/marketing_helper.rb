module MarketingHelper
  # Self-referencing canonical URL for the current marketing page, without the
  # query string so ?locale= variants collapse to one indexable address.
  def marketing_canonical_url
    request.base_url + request.path
  end

  # hreflang alternates: the default locale (and x-default) point at the clean
  # URL; every other locale gets an explicit ?locale= link. Returns
  # [[hreflang, url], ...].
  def marketing_hreflang_alternates
    clean = marketing_canonical_url
    alternates = I18n.available_locales.map do |loc|
      url = loc == I18n.default_locale ? clean : "#{clean}?locale=#{loc}"
      [ loc.to_s, url ]
    end
    alternates + [ [ "x-default", clean ] ]
  end

  def marketing_og_image_url
    request.base_url + "/og-image.png"
  end

  FAQ_COUNT = 6

  # The home-page FAQ, from i18n — used both for the visible section and the
  # FAQPage structured data so they always match.
  def marketing_faq_items
    (1..FAQ_COUNT).map do |i|
      { question: t("marketing.home.faq.q#{i}"), answer: t("marketing.home.faq.a#{i}") }
    end
  end

  def marketing_faq_structured_data
    {
      "@context" => "https://schema.org",
      "@type" => "FAQPage",
      "mainEntity" => marketing_faq_items.map do |item|
        {
          "@type" => "Question",
          "name" => item[:question],
          "acceptedAnswer" => { "@type" => "Answer", "text" => item[:answer] },
        }
      end,
    }
  end

  # Structured data (JSON-LD) describing the product + issuer, as a @graph so
  # Google and LLMs get Organization + SoftwareApplication (with pricing) in one
  # block. Rendered on the marketing home.
  def marketing_structured_data
    base = request.base_url
    {
      "@context" => "https://schema.org",
      "@graph" => [
        {
          "@type" => "Organization",
          "@id" => "#{base}/#organization",
          "name" => "RugSuite ERP",
          "url" => "#{base}/",
          "logo" => "#{base}/icon.png",
          "description" => t("marketing.meta.description"),
          "email" => "sales@rugsuite.app",
          "sameAs" => [],
        },
        {
          "@type" => "SoftwareApplication",
          "name" => "RugSuite ERP",
          "applicationCategory" => "BusinessApplication",
          "operatingSystem" => "Web",
          "url" => "#{base}/",
          "description" => t("marketing.meta.description"),
          "publisher" => { "@id" => "#{base}/#organization" },
          "image" => "#{base}/og-image.png",
          "offers" => [
            { "@type" => "Offer", "name" => "Free",    "price" => "0",  "priceCurrency" => "EUR" },
            { "@type" => "Offer", "name" => "Starter", "price" => "49", "priceCurrency" => "EUR" },
            { "@type" => "Offer", "name" => "Pro",     "price" => "99", "priceCurrency" => "EUR" },
          ],
        },
      ],
    }
  end
end
