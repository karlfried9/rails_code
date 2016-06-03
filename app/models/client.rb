class Client < Company
  has_and_belongs_to_many :venues, join_table: :venue_clients
  has_many :facilities, through: :facility_leases
  has_many :facility_leases
  has_many :inventories

  store_accessor  :config, :ticket_type, :payment_terms, :order_block,
                  :password_regex, :password_validity_period, :domain





  has_many :inventory_tickets, class_name: 'Ticket'
  has_many :confirmed_inventory_options


end