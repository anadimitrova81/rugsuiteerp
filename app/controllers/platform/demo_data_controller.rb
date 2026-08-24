module Platform
  # One-click reseed of the "demo" company, for live demos.
  class DemoDataController < BaseController
    def reseed
      count = DemoCompanySeeder.reseed!
      redirect_to platform_root_path, notice: "Reseeded the demo company with #{count} fresh demo orders."
    rescue => e
      redirect_to platform_root_path, alert: "Reseed failed: #{e.message}"
    end
  end
end
