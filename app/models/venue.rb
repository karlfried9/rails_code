class Venue < Company
  has_many :menus, inverse_of: :venue
  has_many :events, inverse_of: :venue
  has_many :facilities, inverse_of: :venue
  has_many :inventories, inverse_of: :venue
  has_many :facility_leases, inverse_of: :venue
  has_and_belongs_to_many :clients, join_table: :venue_clients


  store_accessor :config, :logo_file_name, :logo_file_size, :logo_content_type, :logo_updated_at, :created_by_client
  def full_address
    if address['address1'] && address['suburb'] && address['postcode'] && address['state']
      address['address1'] + ', ' + address['suburb'] + ', ' + address['postcode'] + ' ' + address['state']
    end
  end
end
