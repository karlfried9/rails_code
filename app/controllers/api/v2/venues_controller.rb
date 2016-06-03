class Api::V2::VenuesController < Api::V2::ApplicationController
  load_and_authorize_resource

  def index

  end

  def show

  end

  def update

  end

  def create
    respond_to_create @venue
  end

  def destroy

  end

  private
  def venue_params
    params.require(:venue).permit(:name)
  end
end