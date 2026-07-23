module Admin
  class UsersController < BaseController
    before_action :require_admin_role, except: :stop_impersonating
    before_action :enforce_user_limit, only: %i[new create]

    def index
      @users = User.order(:email)
    end

    def new
      @user = User.new
    end

    def create
      @user = User.new(user_params)

      if @user.save
        redirect_to admin_users_path, notice: t("admin.user.messages.created", email: @user.email)
      else
        render :new, status: :unprocessable_entity
      end
    end

    def update
      @user = User.find(params[:id])

      if @user.update(user_params)
        redirect_to admin_users_path, notice: t("admin.user.messages.role_updated", email: @user.email)
      else
        redirect_to admin_users_path, alert: t("admin.user.messages.role_update_failed", email: @user.email)
      end
    end

    def destroy
      @user = User.find(params[:id])

      if @user == current_admin
        redirect_to admin_users_path, alert: t("admin.user.messages.cannot_delete_self")
      else
        @user.destroy
        redirect_to admin_users_path, notice: t("admin.user.messages.deleted", email: @user.email)
      end
    end

    def impersonate
      target = User.find(params[:id])

      if target == current_admin
        redirect_to admin_users_path, alert: t("admin.user.messages.cannot_impersonate_self")
      else
        # `||=` keeps the original admin id if we chain-impersonate, so "stop"
        # always restores all the way back rather than to an intermediate hop.
        session[:true_admin_id] ||= current_admin.id
        session[:admin_id] = target.id
        redirect_to admin_requests_path, notice: t("admin.user.messages.impersonating", email: target.email)
      end
    end

    def stop_impersonating
      if session[:true_admin_id].present?
        session[:admin_id] = session.delete(:true_admin_id)
        redirect_to admin_users_path, notice: t("admin.user.messages.stopped_impersonating")
      else
        redirect_to admin_requests_path
      end
    end

    private

    def require_admin_role
      redirect_to admin_requests_path, alert: t("admin.user.messages.admin_only") unless current_admin&.admin?
    end

    # Block adding users once the factory hits its plan's seat limit; point the
    # admin at the plan page. The model validation is the backstop.
    def enforce_user_limit
      return unless current_factory.user_limit_reached?

      redirect_to admin_users_path,
                  alert: t("admin.limits.user.reached_admin", limit: current_factory.user_limit)
    end

    def set_user = @user = User.find(params[:id])

    def user_params
      params.require(:user).permit(:email, :password, :password_confirmation, :role)
    end
  end
end
