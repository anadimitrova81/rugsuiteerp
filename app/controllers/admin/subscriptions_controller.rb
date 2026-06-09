module Admin
  class SubscriptionsController < BaseController
    before_action :require_admin_role

    def show
      @factory = current_factory
    end

    # Plan change without payment processing — placeholder until Stripe is
    # wired in. The Factory model already validates plan inclusion in
    # Factory::PLANS, so an invalid plan bounces here as a 422.
    def update
      @factory = current_factory
      if @factory.update(subscription_params)
        redirect_to admin_subscription_path,
                    notice: t("admin.subscription.updated", plan: t("plan.#{@factory.plan}"))
      else
        render :show, status: :unprocessable_entity
      end
    end

    private

    def require_admin_role
      return if current_admin&.admin?
      redirect_to admin_requests_path, alert: t("admin.settings.admin_only")
    end

    def subscription_params
      params.require(:factory).permit(:plan)
    end
  end
end
