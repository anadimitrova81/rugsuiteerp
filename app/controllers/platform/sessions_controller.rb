module Platform
  class SessionsController < BaseController
    skip_before_action :require_platform_admin, only: %i[new create]

    def new
      redirect_to platform_root_path and return if current_platform_admin
    end

    def create
      admin = PlatformAdmin.find_by(email: params[:email].to_s.strip.downcase)
      if admin&.authenticate(params[:password])
        reset_session
        session[:platform_admin_id] = admin.id
        redirect_to platform_root_path, notice: "Signed in."
      else
        flash.now[:alert] = "Wrong email or password."
        render :new, status: :unprocessable_entity
      end
    end

    def destroy
      reset_session
      redirect_to platform_login_path, notice: "Signed out."
    end
  end
end
