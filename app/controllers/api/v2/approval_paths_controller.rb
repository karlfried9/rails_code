class Api::V2::ApprovalPathsController < Api::V2::ApplicationController
  load_and_authorize_resource
  # load_resource

  def index

    # if params[:employee_id]
    #   @approval_paths = ApprovalPath.where(
    #       :approval_path_ownable_id  => current_user.id,
    #       :approval_path_ownable_type => 'Employee'
    #   )
    # end

    # Actually have better rules here
    if params[:department_id]
      @approval_paths = current_user.department.approval_paths
    end

    # if params[:employee_id]
    #   @approval_paths = current_user.approval_paths
    # end



    if params[:contains_only]
      @approval_paths = @approval_paths.contains_only params[:contains_any]
    end

    if params[:contains_any]
      @approval_paths = @approval_paths.contains_any params[:contains_any].split(',')
    end

  end


  def create
    if @approval_path.approval_path_ownable_type == 'Employee'
      @approval_path.approval_path_ownable_id = current_user.id
    end

    respond_to_create @approval_path
  end

  def show

  end

  def update
    respond_to_update @approval_path, approval_path_params
  end

  private
  def approval_path_params
    params.require(:approval_path).permit(
        :name, :approval_path_ownable_type, :approval_path_ownable_id,
        :is_active, path:[]
    )
  end
end