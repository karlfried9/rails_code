class Ticket < ActiveRecord::Base
  belongs_to :facility
  belongs_to :inventory
  belongs_to :event_date
  belongs_to :client
  has_one :event, through: :event_date

  # Request the ticket from the configured ticket provider, at the moment this is only Ticketek...
  after_create :request

  delegate :ticketing_event_code, to: :event_date
  delegate :name, to: :event, prefix: true
  delegate :name, to: :facility, prefix: true
  delegate :name, to: :client, prefix: true

  # default_scope -> {where.not(status: 'cancelled')}

  # Created when we do something and ticketek doesn't have tickets ready yet
  scope :unavailable, -> {where(status: 'unavailable')}

  # Ordered from Ticketek, waiting for completion
  scope :transiting, -> {where(status: 'transiting')}

  # Available to the system, not the clients
  scope :available, -> {where(status: 'available')}

  # Released to the suite holder
  scope :released, -> {where(status: 'released')}

  # Cancelled with Ticketek
  scope :cancelled, -> {unscope(:where).where(status: 'cancelled')}

  store_accessor :storage, :storage_type
  store_accessor :storage, :file_name

  def request
    # We delay it because tickets are created in a transaction
    TicketekRequestWorker.perform_in(30.seconds.from_now,id) if client.ticket_type == 'ezyticket'
  end

  def reissue
    TicketekReissueWorker.perform_async(id) if status == 'transiting'
  end

  def cancel
    # TODO Cancel Ticket
    TicketekCancelWorker.perform_async(id)
  end

  def cancelled_succesfully
    update_attributes({
      ticketek_id: nil,
      status: 'cancelled'
    })
  end

end
