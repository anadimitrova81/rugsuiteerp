# Keeps the public demo company (demo.<domain>, linked from the marketing
# site) looking fresh: wipes and recreates its orders with dates re-anchored to
# today, and undoes anything visitors changed while clicking around. Scheduled
# daily (see config/recurring.yml); the platform console has a button for the
# same reseed on demand.
class ReseedDemoCompanyJob < ApplicationJob
  queue_as :default

  def perform
    count = DemoCompanySeeder.reseed!
    Rails.logger.info("[demo] Reseeded '#{DemoCompanySeeder::SLUG}' with #{count} fresh orders")
  end
end
