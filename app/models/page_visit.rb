class PageVisit < ApplicationRecord
  acts_as_tenant :factory

  ROUTE_LABELS = {
    "pages#home" => "Начало",
    "pages#faq" => "Въпроси",
    "pages#contacts" => "Контакти",
    "pages#terms" => "Условия",
    "pages#privacy" => "Поверителност",
    "requests#new" => "Заявка (форма)",
    "requests#show" => "Заявка (детайли)",
    "status#show" => "Провери поръчка",
    "status#short" => "Кратък линк",
  }.freeze

  def self.label_for(route_key)
    ROUTE_LABELS[route_key] || route_key
  end
end
