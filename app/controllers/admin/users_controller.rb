module Admin
  class UsersController < BaseController
    before_action :require_admin_role, except: :stop_impersonating

    def index
      @users = User.order(:email)
    end

    def new
      @user = User.new
    end

    def create
      @user = User.new(user_params)

      if @user.save
        redirect_to admin_users_path, notice: "Потребителят #{@user.email} е създаден успешно."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def update
      @user = User.find(params[:id])

      if @user.update(user_params)
        redirect_to admin_users_path, notice: "Ролята на #{@user.email} е обновена."
      else
        redirect_to admin_users_path, alert: "Неуспешна промяна на ролята за #{@user.email}."
      end
    end

    def destroy
      @user = User.find(params[:id])

      if @user == current_admin
        redirect_to admin_users_path, alert: "Не можете да изтриете собствения си профил."
      else
        @user.destroy
        redirect_to admin_users_path, notice: "Потребителят #{@user.email} е изтрит."
      end
    end

    def impersonate
      target = User.find(params[:id])

      if target == current_admin
        redirect_to admin_users_path, alert: "Не можете да се преобразите в собствения си профил."
      else
        # `||=` keeps the original admin id if we chain-impersonate, so "stop"
        # always restores all the way back rather than to an intermediate hop.
        session[:true_admin_id] ||= current_admin.id
        session[:admin_id] = target.id
        redirect_to admin_requests_path, notice: "Влязохте като #{target.email}."
      end
    end

    def stop_impersonating
      if session[:true_admin_id].present?
        session[:admin_id] = session.delete(:true_admin_id)
        redirect_to admin_users_path, notice: "Върнахте се към собствения си профил."
      else
        redirect_to admin_requests_path
      end
    end

    private

    def require_admin_role
      redirect_to admin_requests_path, alert: "Нямате достъп до управлението на потребители." unless current_admin&.admin?
    end

    def set_user = @user = User.find(params[:id])

    def user_params
      params.require(:user).permit(:email, :password, :password_confirmation, :role)
    end
  end
end
