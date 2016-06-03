class TicketekCancelWorker
  include Sidekiq::Worker
  sidekiq_options queue: :tickets


  def perform(ticket_id)
    puts "Cancelling ticket id: #{ticket_id}"
    @api = TicketProviders::Ticketek::API.new ticket_id
    @api.cancel
  end

end