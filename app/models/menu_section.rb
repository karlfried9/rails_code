class MenuSection < ActiveRecord::Base
  # audited
  default_scope {order(order: :asc)}

  belongs_to  :menu
  belongs_to :menu_special_option

  has_many    :menu_section_items

  validates_presence_of :name

  accepts_nested_attributes_for :menu_section_items, allow_destroy: true
end
