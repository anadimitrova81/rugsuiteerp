# The seeded "default" company is our public live demo, advertised on the
# marketing site as demo.<domain>. Rename its slug (and its placeholder name)
# to match. Data-only; no schema changes.
class RenameDefaultCompanyToDemo < ActiveRecord::Migration[8.1]
  def up
    return if select_value("SELECT 1 FROM factories WHERE slug = 'demo'")

    execute <<~SQL
      UPDATE factories
      SET slug = 'demo',
          name = 'Demo Rug Wash',
          legal_name = 'Demo Rug Wash'
      WHERE slug = 'default'
    SQL
  end

  def down
    execute "UPDATE factories SET slug = 'default' WHERE slug = 'demo'"
  end
end
