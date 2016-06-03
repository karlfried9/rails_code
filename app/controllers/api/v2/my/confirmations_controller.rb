class Api::V2::My::ConfirmationsController < Api::V2::ApplicationController
  def index
    @confirmations = current_user.company.confirmed_inventory_options
    render json: @confirmations
  end
end