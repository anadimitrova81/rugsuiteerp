namespace :routes do
  desc "Run the daily route optimizer for today's open stops"
  task optimize: :environment do
    result = Routes::DailyRouteOptimizer.run
    puts "Ordered #{result[:ordered]} of #{result[:total]} open stops for #{Date.current}."
  end
end
