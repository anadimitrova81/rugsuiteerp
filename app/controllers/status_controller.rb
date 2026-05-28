class StatusController < ApplicationController
  include TracksPublicVisits

  def show
    return unless params[:query]

    @query = params[:query].strip
    if @query.blank?
      @error = "Моля, въведете телефонен номер или номер на поръчка."
    else
      # Phone OR customer_id. Accept any of the common BG phone formats
      # ("0888…", "359888…", "+359888…", with or without spaces) so the
      # customer doesn't have to match the exact shape the record was
      # saved in. customer_id stays an exact match.
      phones = Sms::PhoneNumber.variants(@query)
      @requests = Request.where(phone: phones)
                          .or(Request.where(customer_id: @query))
                          .order(created_at: :desc)
    end
  end

  # Public-facing short link from the price-quote SMS — pre-loads the order
  # without exposing the phone number in the URL.
  def short
    request_record = Request.find_by(status_token: params[:token])
    if request_record
      @requests = [request_record]
      # Pre-fill the search input with the order number so the view's
      # `@query.present?` branch renders the result cards (and the
      # customer can bookmark a tokenless URL by re-submitting the form).
      @query = request_record.customer_id
      render :show
    else
      redirect_to status_path, alert: "Поръчката не е намерена или линкът е изтекъл."
    end
  end
end
