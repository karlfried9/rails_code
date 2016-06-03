# this attaches the flow to the inventory item, so you can in effect have different flows for
# different suites
class ConfirmationFlowInventory < ActiveRecord::Base
  # self.table_name = :confirmation_flows_inventories

  belongs_to :inventory
  belongs_to :confirmation_flow
end
