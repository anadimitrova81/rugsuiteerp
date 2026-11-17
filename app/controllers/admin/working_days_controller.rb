module Admin
  # Admin-only: the weekdays clients can book a pickup on — the default for
  # the year and seasonal periods that override it (e.g. winter: Mon, Wed,
  # Fri). Staff can still schedule any day. Ported from nexus-cleaning.
  class WorkingDaysController < BaseController
    before_action :require_admin_role

    def index
      @default_rule = WorkingDaysRule.default_rule || WorkingDaysRule.new(weekdays: WorkingDaysRule::DEFAULT_WEEKDAYS)
      @periods = WorkingDaysRule.periods.to_a
      @period ||= WorkingDaysRule.new(weekdays: [ 1, 3, 5 ])
    end

    # Adds a seasonal period.
    def create
      @period = WorkingDaysRule.new(period_params)

      if @period.save
        redirect_to admin_working_days_path,
                    notice: t("admin.working_days.period_added",
                              from: l(@period.starts_on), to: l(@period.ends_on), days: @period.long_label)
      else
        render_with_errors(@period)
      end
    end

    # Changes the days of the default rule ("default" creates it on first save).
    def update
      rule = params[:id] == "default" ? WorkingDaysRule.find_or_initialize_by(starts_on: nil, ends_on: nil) : WorkingDaysRule.find(params[:id])
      rule.weekdays = params.dig(:working_days_rule, :weekdays)

      if rule.save
        redirect_to admin_working_days_path, notice: t("admin.working_days.default_saved", days: rule.long_label)
      else
        render_with_errors(rule)
      end
    end

    def destroy
      rule = WorkingDaysRule.find(params[:id])

      if rule.default?
        redirect_to admin_working_days_path, alert: t("admin.working_days.default_not_removable")
      else
        rule.destroy
        redirect_to admin_working_days_path, notice: t("admin.working_days.period_removed")
      end
    end

    private

    def period_params
      params.require(:working_days_rule).permit(:starts_on, :ends_on, weekdays: [])
    end

    def render_with_errors(record)
      @errors = record.errors.full_messages.uniq
      index
      render :index, status: :unprocessable_entity
    end

    def require_admin_role
      redirect_to admin_requests_path, alert: t("admin.reports.admin_only") unless current_admin&.admin?
    end
  end
end
