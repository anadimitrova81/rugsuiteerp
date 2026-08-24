module Admin
  class BaseController < ApplicationController
    before_action :require_admin
    before_action :block_demo_writes

    private

    # Belt-and-braces behind the hidden CTAs: the demo company's admin is a
    # look-but-don't-touch tour, so every mutating request is rejected no
    # matter which entry point it comes through.
    def block_demo_writes
      return unless current_factory.demo?
      return if request.get? || request.head?

      redirect_back fallback_location: admin_requests_path,
                    alert: t("admin.demo.read_only")
    end

    # The demo company's admin is publicly loginable, so it is read-mostly:
    # visitors can work the seeded orders but not create orders or users.
    def block_demo_creation
      return unless current_factory.demo?

      redirect_back fallback_location: admin_requests_path,
                    alert: t("admin.demo.creation_disabled")
    end

    def block_demo_edit
      return unless current_factory.demo?

      redirect_back fallback_location: admin_requests_path,
                    alert: t("admin.demo.read_only")
    end

    # Whole sections hidden in the demo company: settings and plan/billing
    # would let a visitor reconfigure or "subscribe" the shared demo tenant.
    def block_demo_section
      return unless current_factory.demo?

      redirect_to admin_requests_path, alert: t("admin.demo.section_disabled")
    end
  end
end
