module Admin
  class ProcessStepsController < BaseController
    before_action :require_admin_role
    before_action :set_process_step, only: %i[edit update destroy move]

    def new
      @process_step = current_factory.process_steps.new
    end

    def create
      @process_step = current_factory.process_steps.new(process_step_params)
      if @process_step.save
        redirect_to admin_settings_path(anchor: "process-steps"), notice: t("admin.process_steps.created")
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @process_step.update(process_step_params)
        redirect_to admin_settings_path(anchor: "process-steps"), notice: t("admin.process_steps.updated")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @process_step.destroy
      redirect_to admin_settings_path(anchor: "process-steps"), notice: t("admin.process_steps.deleted")
    end

    # Swap this step's position with its neighbour in the given direction.
    def move
      ordered = current_factory.process_steps.ordered.to_a
      index = ordered.index(@process_step)
      target = params[:direction] == "up" ? index - 1 : index + 1

      if index && target.between?(0, ordered.size - 1)
        neighbour = ordered[target]
        ProcessStep.transaction do
          this_pos = @process_step.position
          @process_step.update_column(:position, neighbour.position)
          neighbour.update_column(:position, this_pos)
        end
      end
      redirect_to admin_settings_path(anchor: "process-steps")
    end

    private

    def set_process_step
      @process_step = current_factory.process_steps.find(params[:id])
    end

    def require_admin_role
      return if current_admin&.admin?
      redirect_to admin_requests_path, alert: t("admin.settings.admin_only")
    end

    def process_step_params
      params.require(:process_step).permit(:title, :body, :image)
    end
  end
end
