# One-click login into the demo company's admin, linked from the marketing
# site ("Log in to the demo admin"). Signs the visitor in as the demo admin
# without typing credentials. Only exists on the demo tenant — on any real
# factory it 404s like an unknown route would.
class DemoSessionsController < ApplicationController
  def create
    raise FactoryNotFound unless current_factory.demo?

    admin = User.find_by!(email: DemoCompanySeeder::DEMO_ADMIN_EMAIL)
    session[:admin_id] = admin.id
    redirect_to admin_requests_path, notice: t("admin.login.success")
  end
end
