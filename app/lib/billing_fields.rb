# Country-specific legal identifiers for an invoice party. The three generic
# billing columns are labelled per the company's country:
#   reg — company registration id (billing_eik / recipient_eik)
#   tax — tax / VAT identifier, optional (billing_vat_number / recipient_vat_number)
#   rep — responsible person / legal representative (billing_mol / recipient_mol)
#
# These are legal terms tied to the COUNTRY, not the UI language, so they render
# the same regardless of the locale the tenant is browsing in.
module BillingFields
  PROFILES = {
    "BG" => { reg: "ЕИК/Булстат",           tax: "ДДС №",          rep: "МОЛ" },
    "FR" => { reg: "SIREN / SIRET",          tax: "N° TVA",         rep: "Représentant légal" },
    "TR" => { reg: "Vergi Kimlik No (VKN)",  tax: "Vergi Dairesi",  rep: "Yetkili kişi" },
    "MK" => { reg: "ЕМБС",                   tax: "ЕДБ",            rep: "Управител" },
    "RS" => { reg: "Матични број (МБ)",       tax: "ПИБ",            rep: "Заступник" },
  }.freeze

  # Generic fallback for any other country (uses the common EU VAT convention).
  DEFAULT = { reg: "Company reg. No.", tax: "VAT No.", rep: "Authorised representative" }.freeze

  module_function

  def for(country_code)
    PROFILES.fetch(country_code.to_s.upcase, DEFAULT)
  end
end
