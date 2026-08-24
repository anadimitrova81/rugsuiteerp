module Admin
  class BaseController < ApplicationController
    before_action :require_admin

    private

    # The demo company's admin is publicly loginable, so it is read-mostly:
    # visitors can work the seeded orders but not create orders or users.
    def block_demo_creation
      return unless current_factory.demo?

      redirect_back fallback_location: admin_requests_path,
                    alert: t("admin.demo.creation_disabled")
    end
  end
end
