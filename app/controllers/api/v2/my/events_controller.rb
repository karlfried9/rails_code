class Api::V2::My::EventsController < Api::V2::ApplicationController
  # skip_before_filter :authenticate_with_token, only: :tickets_zip

  def upcoming
    events = Event.includes(:dates, :company).where("status = 'Coming Soon'")
    render json: events
  end

  def tickets_zip
    # @tickets = Event.joins(:inventories).where('inventory.id IN (?)', params[:id]).first.tickets

    # @tickets = Ticket.where(inventory_id: params[:id]).includes(:event)
    # file_name = @tickets.first.event.name.underscore
    @event = Event.includes(:tickets).find(params[:id])
    file_name = @event.name.underscore

    t = Tempfile.new("tickets_temp_zip-#{Time.now}")

    Zip::OutputStream.open(t) { |zos| }

    Zip::File.open(t.path, Zip::File::CREATE) do |zipfile|
      @event.tickets.each do |ticket|
        zipfile.add("#{ticket.file_name}", "public/tickets/#{ticket.file_name}")
      end
    end

    send_file t.path, :type => 'application/zip',
              :disposition => 'attachment',
              :filename => file_name + ".zip"
    t.close

  end
end