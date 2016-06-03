class Inventory < ActiveRecord::Base
  has_one :event, through: :event_date, dependent: :destroy
  belongs_to :facility
  belongs_to :event_date
  belongs_to :client
  belongs_to :venue
  has_one :confirmed_inventory_option

  has_one :confirmation_flow_inventory
  has_one :confirmation_flow, through: :confirmation_flow_inventory

  has_many :tickets

  validates_numericality_of :total_allocated_count, less_than_or_equal_to: :total

  #TODO did I do this? if so, what does it do? DC
  has_many :released_tickets, -> {released}, class_name: 'Ticket'

  has_many :inventory_releases, dependent: :destroy
  has_many :request_attendances, inverse_of: :inventory

  store_accessor :options, :inventory_type, :valuation_complete, :notional_value, :catering_value, :gift_value,
                 :other_value, :inclusions, :has_catering, :ticket_numbers, :is_reward_and_recognition, :is_child_friendly,
                 :host_brief_file_name, :host_brief_file_size, :host_brief_content_type, :host_brief_updated_at,
                 :allocations_require_approval, :guest_nominations_allowed, :direct_allocation_allowed, :bidding_allowed,
                 :guest_nomination_notes, :is_parking_offered, :ask_survey_permission, :confirm_mail_template

  has_attached_file :host_brief, default_url: ''
  # has to come after attached file definition
  include DeletableAttachment
  validates_attachment :host_brief, content_type: { content_type: ['application/pdf'] }



  #delegate :name,       to: :event, prefix: true, allow_nil: true
  delegate :event_type, to: :event, allow_nil: true
  delegate :id,         to: :event, prefix: true, allow_nil: true

  #delegate :start,    to: :event_date, allow_nil: true, prefix: true
  #delegate :finish,    to: :event_date, allow_nil: true, prefix: true
  delegate :event_status,   to: :event_date, allow_nil: true

  delegate :name,       to: :facility, prefix: true, allow_nil: true

  delegate :friendly_name,  to: :venue, prefix: true, allow_nil: true
  delegate :state,          to: :venue, prefix: true, allow_nil: true

  scope :with_time_range, -> (start, finish) { where('(virtual_event_period is not NULL AND virtual_event_period <@ tstzrange(?)) OR (virtual_event_period is NULL AND event_dates.event_period <@ tstzrange(?))', [start, finish], [start, finish]) }
  ##### Venue Concerns
  scope :confirmed, -> { where(ConfirmedInventoryOption.where('inventory_id = inventories.id').arel.exists) }
  scope :unconfirmed, -> {where(ConfirmedInventoryOption.where('inventory_id = inventories.id').arel.exists.not)}


  scope :current, -> {where(EventDate.not_finished.where('id = inventories.event_date_id').arel.exists)}

  scope :sponsorship, -> { where("asset_type = 'sponsorship'") }
  scope :hospitality, -> { where("asset_type = 'hospitality'") }

  scope :for_attendance, -> (inventory_release_id) { joins(:inventory_releases)
                              .where('inventory_releases.id = ?', inventory_release_id).first }

  alias_attribute :event_name, :virtual_event_name

  def event_name
    virtual_event_name.nil? ? event.name : virtual_event_name
  end
  
  before_validation :create_time_range

  attr_writer :event_date_start, :event_date_finish
  define_method :event_date_start, -> { virtual_event_period  && virtual_event_period.begin || event_date.event_period.begin}
  define_method :event_date_finish, -> { virtual_event_period && virtual_event_period.end || event_date.event_period.end}

  def create_time_range
    if @event_date_start && @event_date_finish
      write_attribute(:virtual_event_period, Time.at(@event_date_start).utc...Time.at(@event_date_finish).utc)
    end
  end

  validates_datetime :event_date_start, before: :event_date_finish, before_message: 'time must be before the end time'
  validates_datetime :event_date_finish, after: :event_date_start, after_message: 'time must be after the start time'



  #TODO For the splitting UI -> blank or zero. make it zero as well
  accepts_nested_attributes_for :inventory_releases, reject_if: proc { |attributes| attributes[:total_released_count].blank? }

  #TODO write validator to make sure that allocated count cant be higher than total count

  def self.for_client(client)
    sql = <<-SQL
      SELECT events.name, event_dates.event_period, facilities.name AS facility_name, inventories.status, inventories.options, events.id AS event_id, inventories.id AS inventories_id,
     inventories.created_at,inventories.reserved,inventories.total, events.event_type, companies.friendly_name AS venue,
      (SELECT cast(1 as boolean) FROM confirmed_options WHERE client_id = '#{client}' AND inventories_id = inventories.id LIMIT 1) AS is_confirmed
      FROM events
      JOIN event_dates ON event_dates.event_id = events.id
      JOIN inventories ON inventories.event_date_id = event_dates.id
      JOIN companies ON inventories.company_id = companies.id
      JOIN facilities ON inventories.facility_id = facilities.id
      WHERE inventories.client_id = '#{client}'
    SQL

    self.find_by_sql(sql)
  end


end
