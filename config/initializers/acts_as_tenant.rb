ActsAsTenant.configure do |config|
  # Raise if any tenant-scoped query runs without a current tenant. This is the
  # safety net that prevents accidental cross-tenant data leaks; ALL application
  # code must run inside a `set_current_tenant` filter or
  # `ActsAsTenant.with_tenant(...) { ... }` block.
  config.require_tenant = true
end
