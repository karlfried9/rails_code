class MenuSectionItem < ActiveRecord::Base
  # audited
  default_scope {order(order: :asc)}

  belongs_to :menu_section
  belongs_to :menu_item

  delegate :name, to: :menu_item, prefix: true, allow_nil: true
end
