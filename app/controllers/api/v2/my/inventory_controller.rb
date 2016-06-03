class Api::V2::My::InventoryController < Api::V2::ApplicationController
  skip_before_filter :authenticate_user, only: :tickets_zip

  def index
    inventories = Inventory.includes(
        facility: [],
        confirmed_inventory_option: [],
        client:[],
        released_tickets:[]
    ).joins(event_date: [:event]).where(client_id: current_user[:company_id]).where("now() < upper(event_dates.event_period)")


    render json: inventories
  end

  def tickets_zip
    @inventory = Inventory.includes(event_date:[:event]).find(params[:id])

    @tickets = @inventory.event.tickets.where(client_id: @inventory.client_id)

    file_name = @inventory.event.name.underscore
    t = Tempfile.new("tickets_temp_zip-#{Time.now}")

    Zip::OutputStream.open(t) { |zos| }

    Zip::File.open(t.path, Zip::File::CREATE) do |zipfile|
      @tickets.each do |ticket|
        zipfile.add("#{ticket.file_name}", "public/tickets/#{ticket.file_name}")
      end
    end

    send_file t.path, :type => 'application/zip',
              :disposition => 'attachment',
              :filename => file_name + ".zip"
    t.close

  end
end