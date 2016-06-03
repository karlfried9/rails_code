class Event < ActiveRecord::Base
  include EventUploads
  belongs_to :venue

  has_many :inventories, through: :dates
  has_many :tickets, through: :inventories
  has_many :confirmed_inventory_options, through: :inventories
  has_many :dates, class_name: 'EventDate', dependent: :destroy


  scope :currently_open, -> { where( "events.status IN (?)", ['Open', 'Closing Soon']) }
  scope :reportable, -> { where( "events.status IN (?)", ['Open', 'Closing Soon', 'Closed']) }
  scope :closed, -> { where( status: 'Closed') }
  scope :not_closed, -> { where.not( status: 'Closed') }
  scope :type, ->(type) { where('event_type = ?', type) }
  scope :order_by, ->(sort) { joins(:dates).order('?', sort ) }

  scope :for_attendance, -> (inventory_release_id) { joins(dates: { inventories: :inventory_releases })
                                                    .where('inventory_releases.id = ?', inventory_release_id).first }

  store_accessor :data, :promoter

  validates_presence_of :name, :event_type
  validates :status, inclusion: ['Open', 'Closed', 'Closing Soon', 'Coming Soon']


  def first_start_date
    dates.first.start if dates.first
  end

end
