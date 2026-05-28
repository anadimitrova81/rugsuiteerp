class SessionsController < ApplicationController
  def new
  end

  def create
    admin = User.find_by(email: params[:email])

    if admin&.authenticate(params[:password])
      session[:admin_id] = admin.id
      redirect_to admin_requests_path, notice: "Успешно влизане."
    else
      flash.now[:alert] = "Грешен имейл или парола."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    session.delete(:admin_id)
    session.delete(:true_admin_id)
    redirect_to login_path, notice: "Излязохте от системата."
  end
end
