class FacilityLease < ActiveRecord::Base
  belongs_to :facility
  belongs_to :venue
  belongs_to :client

  before_validation :create_time_range

  attr_writer :start, :finish
  define_method :start, -> { lease_period  && lease_period.begin || '0' }
  define_method :finish, -> { lease_period && lease_period.end || '0' }

  def create_time_range
    write_attribute(:lease_period, Time.at(@start).utc...Time.at(@finish).utc)
  end

  scope :active, -> () { where('now() <@ facility_leases.lease_period AND facility_leases.is_enabled = true') }

  validates_datetime :start, before: :finish, before_message: 'time must be before the end time'
  validates_datetime :finish, after: :start, after_message: 'time must be after the start time'

  delegate :name, to: :client, prefix: true
  delegate :name, to: :venue, prefix: true
  delegate :name, to: :facility, prefix: true

end
