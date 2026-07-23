module Platform
  # Cross-tenant list of every factory ("subscription") + its plan and usage.
  class SubscriptionsController < BaseController
    def index
      @factories = Factory.order(created_at: :desc).to_a
      @usage = @factories.index_with { |factory| usage_for(factory) }
    end

    def show
      @factory = Factory.find(params[:id])
      @usage = usage_for(@factory)
      ActsAsTenant.with_tenant(@factory) do
        @users = User.order(:role, :email).to_a
      end
    end

    private

    # Factory#monthly_orders_used / #users_count read through tenant-scoped
    # associations; run them inside the factory's tenant scope to satisfy the
    # strict acts_as_tenant config.
    def usage_for(factory)
      ActsAsTenant.with_tenant(factory) do
        {
          orders_used: factory.monthly_orders_used,
          order_limit: factory.monthly_order_limit,
          users_used: factory.users_count,
          user_limit: factory.user_limit,
        }
      end
    end
  end
end
