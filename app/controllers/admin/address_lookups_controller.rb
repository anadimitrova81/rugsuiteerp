module Admin
  class AddressLookupsController < BaseController
    def create
      result = GoogleMapsLinkParser.parse(params[:url].to_s)

      if result&.coordinates.present?
        render json: { address: result.coordinates }
      else
        render json: { error: "Не успяхме да извлечем координати от линка." }, status: :unprocessable_entity
      end
    end
  end
end
