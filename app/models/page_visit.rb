class PageVisit < ApplicationRecord
  acts_as_tenant :factory

  # Translated via I18n under admin.page_visit_labels.<route_key>.
  def self.label_for(route_key)
    I18n.t("admin.page_visit_labels.#{route_key}", default: route_key)
  end
end
