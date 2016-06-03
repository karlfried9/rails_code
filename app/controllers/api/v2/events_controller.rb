class Api::V2::EventsController < Api::V2::ApplicationController
  load_and_authorize_resource

  def index
    @events.includes!(:dates)

    if params[:status]
      @events = @events.where(status: params[:status])
    else
      @events = @events.not_closed
    end

    if params[:venue_id]
      @events = @events.where(venue_id: params[:venue_id])
    end

  end

  def calendar
    # TODO fix data source
    @res = JSON.parse(open('inventories?client_id=' + current_user.company_id).read)
    names = @res.map { |e| e['event_name'] }
    @events = Event.where(name: names).includes(:dates, :inventories).select("(array_agg(events.id))[1] as id, max(events.event_type) as event_type, name").group(:name)
  end

  def show
  end

  def update
    respond_to_update @event, event_params
  end

  def create
    respond_to_create @event
  end

  def destroy
  end


  private

  def event_params
    params.require(:event).permit(
        :name, :description, :event_type, :status,
        :tile, :agenda, :menu, :delete_tile, :delete_agenda,
        :delete_menu, :promoter
    )
  end
end
