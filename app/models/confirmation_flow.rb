class ConfirmationFlow < ActiveRecord::Base
  # has_many :confirmable_flow_items
  has_many :confirmation_flow_sections
  has_many :confirmation_flow_inventories
  has_many :inventories, through: :confirmation_flow_inventories

  accepts_nested_attributes_for :confirmation_flow_sections, allow_destroy: true

end
