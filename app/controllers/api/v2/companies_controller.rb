class Api::V2::CompaniesController < Api::V2::ApplicationController
  load_and_authorize_resource
  # skip_load_and_authorize_resource only: :index

  def index
    # if current_user.is_venue_admin?
    #   @companies = current_user.company.clients.includes(manager:[:profile])
    # elsif current_user.super_admin?
    #   @companies = Company.includes(manager:[:profile]).all
    # end
    #
    # render json: @companies
  end

  def show
    head :not_found unless @company
    render json: @company if @company
  end

  def create
    @company = Company.new company_params

    @company.company_type = 'company' if current_user.is_venue_admin?

    if @company.save
      current_user.company.clients << @company
      render json: @company, status: :created
    else
      render json: @company.errors, status: :unprocessable_entity
    end

  end

  def update
    if @company.update_attributes company_params
      render json: @company
    else
      render json: @company.errors, status: :unprocessable_entity
    end
  end

  def destroy
  end

  private
  def company_params
    params.permit(
        :name, :friendly_name,
        :address1, :address2, :suburb, :state, :city,
        :state, :postcode, :ticket_type, :phone, :fax,
        :notify_sms, :notify_email, :company_type, :payment_terms, :order_block, :manager_id
    )
  end
end
