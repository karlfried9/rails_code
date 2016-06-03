class Facility < ActiveRecord::Base
  belongs_to :venue
  has_many :inventories
  has_many :leasees, through: :facility_leases, class_name: 'Client', source: :client
  has_many :facility_leases

  has_one :current_active_lease, -> { where('now() <@ facility_leases.lease_period AND facility_leases.is_enabled = true') }, class_name: 'FacilityLease'

  accepts_nested_attributes_for :facility_leases


  validates_presence_of :name, :venue, :capacity, :facility_type
  validates_numericality_of :capacity, minimum: 1

end
