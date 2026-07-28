# Tenant-side consumer of a platform-admin impersonation token. Runs in the
# ApplicationController (tenant) stack, so `current_factory` is the subdomain's
# factory. Token-gated rather than login-gated, since the platform operator has
# no tenant account.
class PlatformHandoffsController < ApplicationController
  def show
    data = Rails.application.message_verifier(:platform_impersonation)
                .verified(params[:token].to_s, purpose: :impersonation)

    return reject unless data.is_a?(Hash)
    # A token minted for one tenant must not be replayable against another.
    return reject unless data["factory_id"] == current_factory.id

    user = User.find_by(id: data["user_id"])
    return reject unless user

    reset_session
    session[:admin_id] = user.id
    session[:platform_impersonator_id] = data["platform_admin_id"]

    Rails.logger.info(
      "[platform] impersonation entered factory=#{current_factory.slug} " \
      "user=#{user.id} operator_admin=#{data['platform_admin_id']}",
    )
    redirect_to admin_requests_path, notice: t("admin.impersonation.platform_entered", email: user.email)
  end

  # End a platform impersonation and return to the operator console.
  def destroy
    session.delete(:admin_id)
    session.delete(:platform_impersonator_id)

    host = HostType.platform_host(request.host)
    port = [ 80, 443 ].include?(request.port) ? "" : ":#{request.port}"
    redirect_to "#{request.scheme}://#{host}#{port}/", allow_other_host: true
  end

  private

  def reject
    reset_session
    render plain: "Invalid or expired impersonation link.", status: :bad_request
  end
end
