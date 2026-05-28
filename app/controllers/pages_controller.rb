class PagesController < ApplicationController
  include TracksPublicVisits

  def home
    redirect_to admin_requests_path and return if admin_logged_in?
    @show_welcome = params[:welcome].present?
  end

  def faq
  end

  def contacts
  end

  def terms
  end

  def privacy
  end
end
