class Api::V2::ClientsController < Api::V2::ApplicationController
  load_and_authorize_resource

  def index
  end

  def show
  end

  def update
  end

  def create
  end

  def destroy
  end

  private
  def client_params
    params.require(:client).permit(:name)
  end
end
