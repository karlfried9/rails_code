class TicketekReissueWorker
  include Sidekiq::Worker
  sidekiq_options queue: :tickets


  def perform(ticket_id)
    puts "Reissuing for ticket id: #{ticket_id}"
    @api = TicketProviders::Ticketek::API.new ticket_id
    @api.reissue
  end


end