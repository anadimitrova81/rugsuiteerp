module Admin
  class AddressLookupsController < BaseController
    def create
      result = GoogleMapsLinkParser.parse(params[:url].to_s)

      if result&.coordinates.present?
        render json: { address: result.coordinates }
      else
        render json: { error: t("admin.address_lookups.parse_error") }, status: :unprocessable_entity
      end
    end
  end
end
