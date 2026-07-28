module Platform
  # Cross-tenant list of every invoice issued to any factory. Optionally
  # filtered to one factory via ?factory_id=.
  class InvoicesController < BaseController
    def index
      # Invoice is tenant-scoped; this console spans all tenants, so read it
      # outside any tenant scope. Eager-load the factory for the name column.
      ActsAsTenant.without_tenant do
        scope = Invoice.includes(:factory).chronological
        scope = scope.where(factory_id: params[:factory_id]) if params[:factory_id].present?
        @invoices = scope.to_a
        @total_cents = @invoices.sum(&:amount_cents)
      end
    end

    def show
      ActsAsTenant.without_tenant do
        invoice = Invoice.find(params[:id])
        send_data InvoicePdf.new(invoice).render,
                  filename: "faktura-#{invoice.number}.pdf",
                  type: "application/pdf",
                  disposition: "inline"
      end
    end
  end
end
