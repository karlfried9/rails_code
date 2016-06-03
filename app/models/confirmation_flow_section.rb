class ConfirmationFlowSection < ActiveRecord::Base
  has_many :confirmation_flow_items
  belongs_to :confirmation_flow

  accepts_nested_attributes_for :confirmation_flow_items, allow_destroy: true

end
