class TicketekRequestWorker
  include Sidekiq::Worker
  sidekiq_options queue: :tickets

  def perform(ticket_id)
    puts "Asking for ticket id: #{ticket_id}"
    @api = TicketProviders::Ticketek::API.new ticket_id
    @api.request
  end

end