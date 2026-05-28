module Routes
  class OptimizeDailyRouteJob < ApplicationJob
    queue_as :default

    def perform
      result = Routes::DailyRouteOptimizer.run
      Rails.logger.info("[optimize_daily_route_job] ordered #{result[:ordered]}/#{result[:total]} stops for #{Date.current}")
    end
  end
end
