module Admin
  # "Statistics": client analytics (new vs returning, frequency, top clients)
  # with monthly charts. Ported from nexus-cleaning.
  class ClientReportsController < BaseController
    before_action :require_admin_role

    MONTHS_PER_PAGE = 6

    def index
      @grouping = params[:by] == "year" ? :year : :month
      @analytics = ClientAnalytics.new(Request.where.not(status: "cancelled"),
                                       country: current_factory.phone_country,
                                       time_zone: current_factory.timezone)

      periods = @analytics.periods(@grouping)
      @chart_months = (@grouping == :month ? periods : @analytics.periods(:month)).reverse.map do |p|
        p.merge(date: Date.strptime(p[:key], "%Y-%m"))
      end
      if @grouping == :month
        @page = [ params[:page].to_i, 1 ].max
        @periods = periods.slice((@page - 1) * MONTHS_PER_PAGE, MONTHS_PER_PAGE) || []
        @has_more = periods.size > @page * MONTHS_PER_PAGE
      else
        @periods = periods
      end

      # Only "load more" (?page=N as a Turbo Stream) appends; everything else
      # renders the full page.
      if params[:page].present? && request.format.turbo_stream?
        render :index
      else
        render :index, formats: [ :html ]
      end
    end

    private

    def require_admin_role
      redirect_to admin_requests_path, alert: t("admin.reports.admin_only") unless current_admin&.admin?
    end
  end
end
