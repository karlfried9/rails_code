class ConfirmationFlowItem < ActiveRecord::Base
  belongs_to :confirmable_flow_item, polymorphic: true
  belongs_to :confirmation_flow
end
