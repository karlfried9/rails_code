class Api::V2::CompanyConfigsController < Api::V2::ApplicationController
  load_resource except: :show
  authorize_resource

  def index
    # @menus = Menu.includes(:sections, :items).all
    # render json: @menus, root: :menu
    @company_configs = CompanyConfig.where(company_id: current_user.company.id)
    if @company_configs.blank?
      render json: []
    else
      @company_config = @company_configs[0]
      render
    end
  end


  def update

    if @company_config.update_attributes company_config_params
      render 'index'
    else
      render json: @company_config.errors, status: :unprocessable_entity
    end
  end

  def destory
    if @company_config.destroy
      head :no_content
    else
      render json: {__errors: @company_config.errors}, status: :unprocessable_entity
    end
  end

  def create
    if @company_config.save
      render 'index'
    else
      render json: @company_config.errors, status: :unprocessable_entity
    end
  end

  private
  def company_config_params
    params.require(:company_config).permit(
        :logos, :brandings, :logos_file_name, :brandings_file_name, :delete_logos, :delete_brandings, :senior_gatekeeper,
        :always_approve, :default_business_unit, :password_regex, :help, :default_confirmation_template
    )
  end
end
