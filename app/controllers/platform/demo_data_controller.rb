module Platform
  # One-click reseed of the "default" demo company, for live demos.
  class DemoDataController < BaseController
    def reseed
      count = DefaultCompanySeeder.reseed!
      redirect_to platform_root_path, notice: "Reseeded the default company with #{count} fresh demo orders."
    rescue => e
      redirect_to platform_root_path, alert: "Reseed failed: #{e.message}"
    end
  end
end
