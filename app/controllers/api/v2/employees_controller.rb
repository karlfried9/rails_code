class Api::V2::EmployeesController < Api::V2::ApplicationController
  skip_before_filter :authenticate_user, only: [:password_reset]

  load_and_authorize_resource

  def index
    @fields = params[:fields].split ',' if params[:fields]
    @ids = params[:ids].split ',' if params[:ids]

    @employees = Employee.where(id: @ids) if @ids

    @employees = @employees.preload(:profile).includes :department

    @employees = @employees.search(params[:search]) if params[:search]

  end

  def show
  end

  def create
    respond_to_create @employee
  end

  def update
    respond_to_update @employee, employee_params
  end

  def destroy
    if @employee.destroy
      head :no_content
    else
      head :unprocessable_entity
    end
  end

  def save_password
    @employee = Employee.find(params[:id])
    @employee.password = params[:password]
    @employee.password_reset_date = Time.now
    if @employee.save
      render json: { message: 'Your Password has bean changed' }, status: :ok
    else
      render json: @employee.errors, status: :unprocessable_entity
    end
  end

  def password_reset
    if params[:token] && params[:password]
      @employee = Employee.for_password_token(params[:token])
      @employee.password = params[:password]
      @employee.password_reset_date = Time.now
      if @employee.password.downcase.include?(@employee.profile.first_name.downcase) || @employee.password.downcase.include?(@employee.profile.last_name.downcase)
        render json: {message: "The password chosen must not contain all or part of the user's account name."}, status: :unprocessable_entity
      else
        if @employee.save
          render json: { message: 'Your account has been confirmed' }, status: :ok
        else
          render json: @employee.errors, status: :unprocessable_entity
        end
      end
    else
      render json: { message: 'Not all activation params were provided.' }, status: :unprocessable_entity
    end
  end

  def report_incorrect_data
    manager = Employee.find_by_id(current_user.company.manager_id)
    if params[:comment]
      MailgunMailer.report_incorrect_profile_data(manager, current_user, params[:comment])

      render json: { message: 'Issue is reported to company manager' }, status: :ok
    else
      render json: { message: 'Comment must be provided.' }, status: :unprocessable_entity
    end
  end

  private

  def employee_params
    params.require(:employee).permit(:company_id, :email, :department_id, :state, :can_login?,
                                     :position, :cost_center, :bi_access, :internal_id, :password, :title, :can_use_crm, :job_title,
                                     :password_confirmation, :client_admin, :venue_admin, :standard_user, :department_admin, :gatekeeper_role,
                                     profile_attributes: [:id, :first_name, :last_name, :sex, :klass, :mobile_number],
                                     department_gatekeepers_attributes: [:id, :_destroy, :department_id]
    )
  end

  # def fetch_employee
  #   if current_user.is_super_admin?
  #     @employee = Employee.find_by_id(params[:id])
  #   else
  #     @employee = Employee.find_by(company_id: params[:company_id], id: params[:id])
  #   end
  #   render json: { employee: { error: 'Employee not found.' } },
  #          status: :unprocessable_entity unless @employee.present?
  #TODO why on earth are you doing a 422?
  # end

  def permissions
    params[:employee][:permissions]
  end

  def generate_approval_path
    [
        params[:employee][:first_manager],
        params[:employee][:second_manager],
        params[:employee][:third_manager]
    ]

  end
end
