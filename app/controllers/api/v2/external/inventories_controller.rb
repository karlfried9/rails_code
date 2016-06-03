class Api::V2::External::InventoriesController < Api::V2::External::ApplicationController

  def index
    client_id = params[:client_id]
    @inventories = Inventory.includes(:venue, :event_date, :event).where(client_id: client_id).current.references :event_date

    if params[:start]
      start = params[:start]
    end

    if params[:finish]
      finish = params[:finish]
    end

    if start && finish
      start = finish if start > finish
      finish = start if finish < start

      #TODO make sure hospitality events are released by the venue!
      @inventories = @inventories.merge(Inventory.with_time_range(start, finish))
    end
  end



end