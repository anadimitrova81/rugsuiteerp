module Admin
  class SubscriptionsController < BaseController
    before_action :require_admin_role

    def show
      @factory = current_factory
    end

    # Plan change without payment processing — placeholder until Stripe is
    # wired in. Downgrades (incl. to free) go straight through here; upgrades to
    # a billable plan are routed through #billing first to collect legal details.
    def update
      @factory = current_factory
      if @factory.update(subscription_params)
        if @factory.saved_change_to_plan? && @factory.billable_plan?
          SubscriptionInvoicer.issue_for_plan_change(@factory)
        end
        redirect_to admin_subscription_path,
                    notice: t("admin.subscription.updated", plan: t("plan.#{@factory.plan}"))
      else
        render :show, status: :unprocessable_entity
      end
    end

    # Billing-details form shown before switching to a billable plan. Prefilled
    # from any details the tenant already saved.
    def billing
      @factory = current_factory
      @plan = requested_plan
      redirect_to admin_subscription_path and return unless @plan
    end

    # Collects the legal billing details, switches the plan, and issues the
    # first invoice. Requires the mandatory фактура fields.
    def update_billing
      @factory = current_factory
      @plan = requested_plan
      redirect_to admin_subscription_path and return unless @plan

      @factory.assign_attributes(billing_params)
      @factory.plan = @plan

      if @factory.billing_details_complete? && @factory.save
        SubscriptionInvoicer.issue_for_plan_change(@factory) if @factory.saved_change_to_plan?
        redirect_to admin_invoices_path,
                    notice: t("admin.subscription.updated", plan: t("plan.#{@factory.plan}"))
      else
        @factory.errors.add(:base, t("admin.subscription.billing.incomplete")) unless @factory.billing_details_complete?
        render :billing, status: :unprocessable_entity
      end
    end

    private

    # Only billable plans go through the billing flow.
    def requested_plan
      plan = params[:plan].presence
      plan if plan && Factory::PLAN_PRICES[plan].to_i.positive?
    end

    def require_admin_role
      return if current_admin&.admin?
      redirect_to admin_requests_path, alert: t("admin.settings.admin_only")
    end

    def subscription_params
      params.require(:factory).permit(:plan)
    end

    def billing_params
      params.require(:factory).permit(
        :billing_company_name, :billing_address, :billing_eik,
        :billing_vat_number, :billing_mol,
      )
    end
  end
end
