module Admin
  class InvoicesController < BaseController
    before_action :require_admin_role

    def index
      # acts_as_tenant scopes to the current factory automatically.
      @invoices = Invoice.chronological
    end

    def show
      @invoice = Invoice.find(params[:id])
      respond_to do |format|
        format.html
        format.pdf do
          send_data InvoicePdf.new(@invoice).render,
                    filename: "faktura-#{@invoice.number}.pdf",
                    type: "application/pdf",
                    disposition: "inline"
        end
      end
    end

    private

    def require_admin_role
      return if current_admin&.admin?
      redirect_to admin_requests_path, alert: t("admin.settings.admin_only")
    end
  end
end
