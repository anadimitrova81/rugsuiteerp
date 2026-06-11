class PagesController < ApplicationController
  include TracksPublicVisits

  def home
    redirect_to admin_requests_path and return if admin_logged_in?
    @show_welcome = params[:welcome].present?
    @process_steps = process_steps_for_display
  end

  def faq
  end

  def contacts
  end

  def terms
  end

  def privacy
  end

  private

  # The "How it works" steps shown on the home page. A factory that has defined
  # its own steps gets those (in order); otherwise we fall back to the built-in
  # default journey shipped as static assets + locale text. Each entry exposes
  # :title, :body, and :image (an Active Storage attachment, an asset filename
  # string, or nil when a custom step has no image yet).
  def process_steps_for_display
    steps = current_factory.process_steps.ordered
    if steps.any?
      steps.map do |step|
        { title: step.title, body: step.body.to_s, image: (step.image if step.image.attached?) }
      end
    else
      (1..6).map do |n|
        ext = [3, 4, 5].include?(n) ? "png" : "jpg"
        {
          title: t("home.how_it_works.step_#{n}.title"),
          body: t("home.how_it_works.step_#{n}.body", pickup_window: current_factory.pickup_window),
          image: "step#{n}.#{ext}",
        }
      end
    end
  end
end
