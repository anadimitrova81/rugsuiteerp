class SessionsController < ApplicationController
  def new
  end

  def create
    admin = User.find_by(email: params[:email])

    if admin&.authenticate(params[:password])
      session[:admin_id] = admin.id
      redirect_to admin_requests_path, notice: t("admin.login.success")
    else
      flash.now[:alert] = t("admin.login.invalid")
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    session.delete(:admin_id)
    session.delete(:true_admin_id)
    redirect_to login_path, notice: t("admin.login.logout")
  end
end
