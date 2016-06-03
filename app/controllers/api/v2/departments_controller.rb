class Api::V2::DepartmentsController < Api::V2::ApplicationController
  load_and_authorize_resource

  def index

    if params[:allocation_type]
      @departments = @departments.where 'allocation_type @> ARRAY[?]::varchar[]', params[:allocation_type]
    end

    if params[:include_child_counts]
      @departments = @departments.includes(:children)
      @include_child_counts = true
    end

    if params[:is_partitioning_point]
      @departments = Department.where(is_partitioning_point: params[:is_partitioning_point], company_id: current_user.company_id, deleted_at: nil)
    end
  end

  def show

  end


  def update
    respond_to_update @department, department_params
  end

  def create
    respond_to_create @department
  end

  def destroy
    if @department.destroy
      head :no_content
    else
      render json: {__errors: @department.errors}, status: :unprocessable_entity
    end
  end

  private
  def department_params
    params.require(:department).permit(
        :id, :name, :formal_name, :owner_id, :secondary_owner_id, :secondary_owner_active, :display_order,
        :percent_allocation, :parent_id, :is_partitioning_point, allocation_type: [],
        department_gatekeepers_attributes: [:id, :_destroy, :employee_id]
    )
  end
end
