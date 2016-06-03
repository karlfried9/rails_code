class Api::V2::DatesController < Api::V2::ApplicationController
  load_and_authorize_resource :event
  load_and_authorize_resource :event_date, through: :event

  def index
  end

  def show
  end

  def update
    respond_to_update @event_date, event_date_params
  end

  def destroy
  end

  def create
    respond_to_create @event_date
  end


  ## Facilities for releasing an event date into the inventory
  def release
    release_data = EventDate.data_for_release(params[:date_id])
    render json: release_data.to_json
  end

  ## Reporting shit
  def confirmations
    confirmations = EventDate.find(params[:id]).includes(:confirmed_inventory_options)
    render json: confirmations.to_json
  end

  private
  def event_date_params
    params.require(:event_date).permit(
        :start, :finish, :ticketing_event_code,  :tile, :agenda, :menu, :delete_tile, :delete_agenda,
        :delete_menu, :promoter, :status
    )
  end
end
