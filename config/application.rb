require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Rugsuiteerp
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # Global default is UTC; per-tenant display timezones come from
    # `Factory#timezone` and are read at request time.
    config.time_zone = "UTC"

    # I18n. Default is English; per-tenant locales come from
    # `Factory#default_locale` and are set per request in ApplicationController.
    config.i18n.default_locale = :en
    config.i18n.available_locales = [:en, :bg]
    config.i18n.fallbacks = [:en]
    # config.eager_load_paths << Rails.root.join("extras")

    config.autoload_paths << Rails.root.join("app/form_builders")
    config.action_view.default_form_builder = "ApplicationFormBuilder"

    # Disable the default field_with_errors div wrapper — the form builder handles errors inline.
    config.action_view.field_error_proc = proc { |html_tag, _instance| html_tag }
  end
end
