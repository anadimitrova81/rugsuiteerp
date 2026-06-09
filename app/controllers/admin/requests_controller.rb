module Admin
  class RequestsController < BaseController
    PER_PAGE = 25

    def index
      @query = params[:q].to_s.strip
      @from_date = parse_date(params[:from]) if current_admin.admin?
      @to_date = parse_date(params[:to]) if current_admin.admin?

      if current_admin.courier?
        load_courier_index
      elsif current_admin.operator?
        load_operator_index
      elsif current_admin.coordinator?
        load_coordinator_index
        @pending_price_notifications_count = pending_price_notifications_count
      elsif @query.present? && current_admin.admin?
        like = "%#{@query}%"
        scope = admin_scope.where("phone ILIKE :q OR customer_id ILIKE :q", q: like).order(created_at: :desc)
        paginate(scope, scope.count)
        @pending_price_notifications_count = pending_price_notifications_count
      else
        @tab_statuses = Request.statuses_for(current_admin.role)
        @status_counts = admin_scope.group(:status).count
        requested = params[:status]
        @current_status = @tab_statuses.include?(requested) ? requested : @tab_statuses.first
        scope = admin_scope.where(status: @current_status).order(created_at: :desc)
        paginate(scope, @status_counts[@current_status].to_i)
        @pending_price_notifications_count = pending_price_notifications_count
      end

      # Only the "load more" button appends rows — it sends ?page=N as a Turbo
      # Stream. Every other hit (including the Turbo form redirect after saving
      # a request, which also accepts turbo streams) must render the full list.
      if params[:page].present? && request.format.turbo_stream?
        render :index
      else
        render :index, formats: [:html]
      end
    end

    def show
      @request = scoped_requests.find(params[:id])
    end

    def new
      @request = Request.new
    end

    def create
      @request = Request.new(request_params)

      if @request.save
        redirect_to admin_request_path(@request), notice: "Поръчката е създадена успешно."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @request = scoped_requests.find(params[:id])
      @statuses = Request.statuses_for(current_admin.role)
    end

    def update
      @request = scoped_requests.find(params[:id])

      if @request.update(request_params)
        redirect_to admin_requests_path, notice: "Поръчка #{@request.customer_id} е обновена успешно."
      elsif current_admin.courier?
        flash.now[:alert] = "Поръчка ##{@request.customer_id}: #{@request.errors.full_messages.to_sentence}"
        @request.status = @request.status_in_database
        @failed_request = @request
        load_courier_index
        render :index, status: :unprocessable_entity
      elsif current_admin.operator?
        @request.status = @request.status_in_database
        @failed_request = @request
        load_operator_index
        render :index, status: :unprocessable_entity
      elsif current_admin.coordinator?
        @request.status = @request.status_in_database
        @failed_request = @request
        load_coordinator_index
        render :index, status: :unprocessable_entity
      else
        @statuses = Request.statuses_for(current_admin.role)
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def load_courier_index
      @courier_tabs = Request::COURIER_TABS
      requested_tab = params[:tab].to_s
      @current_tab = @courier_tabs.key?(requested_tab) ? requested_tab : "today"

      mine_clause = "((status IN ('pickup_confirmed','picked_up') AND pickup_courier_id = :u) " \
                    "OR (status IN ('delivery_confirmed','delivered') AND delivery_courier_id = :u))"

      @tab_counts = @courier_tabs.keys.index_with do |tab|
        Request.courier_today_scope(tab).where(mine_clause, u: current_admin.id).count
      end
      @requests = Request.courier_today_scope(@current_tab)
                         .where(mine_clause, u: current_admin.id)
                         .order(Arel.sql("route_position NULLS LAST"))
                         .order(:pick_up_at, :delivery_at, :created_at)

      tz = Request.factory_tz_sql
      collected_today = Request.where(status: "delivered", delivery_courier_id: current_admin.id)
                               .where("(delivery_at AT TIME ZONE 'UTC' AT TIME ZONE '#{tz}')::date = ?", Date.current)
      @collected_total = collected_today.sum(:amount).to_f
      @collected_count = collected_today.count
      @collected_total_card = collected_today.where(paid_by_card: true).sum(:amount).to_f
      @collected_total_cash = @collected_total - @collected_total_card
    end

    def load_operator_index
      @operator_tabs = Request::OPERATOR_TABS
      requested_tab = params[:tab].to_s
      @current_tab = @operator_tabs.key?(requested_tab) ? requested_tab : "received"
      @tab_counts = @operator_tabs.keys.index_with { |tab| Request.operator_scope(tab).count }
      @requests = Request.operator_scope(@current_tab).order(:pick_up_at, :created_at)
    end

    def load_coordinator_index
      @coordinator_tabs = Request::COORDINATOR_TABS
      requested_tab = params[:tab].to_s
      @current_tab = @coordinator_tabs.key?(requested_tab) ? requested_tab : "new"
      @tab_counts = @coordinator_tabs.keys.index_with { |tab| Request.coordinator_scope(tab).count }
      @requests = Request.coordinator_scope(@current_tab).order(:pick_up_at, :delivery_at, :created_at)
    end

    def scoped_requests = Request.where(status: Request.statuses_for(current_admin.role))

    # Admin-side scope that also applies the date range filter when set.
    # Uses delivery_at for orders already on the delivery leg
    # (delivery_confirmed / delivered) and pick_up_at otherwise — that
    # matches how the admin thinks about each order's "active date".
    def admin_scope
      scope = scoped_requests
      return scope unless @from_date || @to_date

      tz = Request.factory_tz_sql
      date_expr =
        "((CASE WHEN status IN ('delivery_confirmed', 'delivered') " \
        "THEN delivery_at ELSE pick_up_at END) " \
        "AT TIME ZONE 'UTC' AT TIME ZONE '#{tz}')::date"

      if @from_date && @to_date
        scope.where("#{date_expr} BETWEEN :from AND :to", from: @from_date, to: @to_date)
      elsif @from_date
        scope.where("#{date_expr} >= :from", from: @from_date)
      else
        scope.where("#{date_expr} <= :to", to: @to_date)
      end
    end

    def parse_date(value)
      Date.iso8601(value.to_s) if value.present?
    rescue ArgumentError, Date::Error
      nil
    end

    # Loads one page of `scope` and records whether more rows remain, so the
    # view can show a "load more" button. `total` is the full count for the
    # current filter (already computed for the status tabs).
    def paginate(scope, total)
      @page = [params[:page].to_i, 1].max
      @requests = scope.limit(PER_PAGE).offset((@page - 1) * PER_PAGE)
      @has_more = total > @page * PER_PAGE
    end

    def pending_price_notifications_count
      Request.awaiting_price_notification.where.not(amount: nil).count
    end

    def request_params
      params.
        require(:request).
        permit(:phone, :city, :address, :verified_address, :pick_up_at, :delivery_at, :status, :pick_up_notes, :delivery_notes, :items_only, :number_of_items, :weight, :voucher, :bulk_price, :paid_by_card)
    end
  end
end
