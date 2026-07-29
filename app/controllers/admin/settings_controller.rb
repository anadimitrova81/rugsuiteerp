module Admin
  class SettingsController < BaseController
    before_action :require_admin_role

    def show
      @factory = current_factory
    end

    def update
      @factory = current_factory
      if @factory.update(settings_params)
        redirect_to admin_settings_path, notice: t("admin.settings.updated")
      else
        render :show, status: :unprocessable_entity
      end
    end

    private

    # Only the admin role can touch settings — coordinators/operators/couriers
    # see other admin pages but not this one.
    def require_admin_role
      return if current_admin&.admin?
      redirect_to admin_requests_path, alert: t("admin.settings.admin_only")
    end

    def settings_params
      params.require(:factory).permit(
        :name, :legal_name, :phone, :email,
        :pickup_window, :business_hours, :same_day_cutoff_hour,
        { service_cities: [] },
        :facebook_url, :instagram_url, :viber_url, :whatsapp_url,
        :pricing_mode,
        :price_per_kg, :price_per_kg_bulk, :bulk_weight_threshold,
        :price_per_sqm, :price_per_sqm_bulk, :bulk_area_threshold,
        :price_per_item,
        :brand_primary_color, :brand_secondary_color,
        :logo, :hero_image,
      )
    end
  end
end
