class PagesController < ApplicationController
  include TracksPublicVisits

  def home
    # Staff landing on their own site go straight to the admin — except on the
    # demo company, where marketing visitors (already auto-logged-in as the
    # demo admin) must still be able to see the customer-facing page.
    redirect_to admin_requests_path and return if admin_logged_in? && !current_factory.demo?
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
        { title: step.title, body: step.body.to_s, image: step.image.attached? ? step.image : nil }
      end
    else
      (1..6).map do |n|
        {
          title: t("home.how_it_works.step_#{n}.title"),
          body: t("home.how_it_works.step_#{n}.body", pickup_window: current_factory.pickup_window),
          image: default_step_image(n),
        }
      end
    end
  end

  def default_step_image(n)
    ext = [3, 4, 5].include?(n) ? "png" : "jpg"
    "step#{n}.#{ext}"
  end
end
