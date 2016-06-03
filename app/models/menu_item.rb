class MenuItem < ActiveRecord::Base
  # audited
  include MultiplePrices

  belongs_to :menu_item_category
  counter_culture :menu_item_category

  belongs_to :venue
  has_many :menu_section_items

  # Premium Items are shown in certain places, i.e after a standard drinks list is selected
  store_accessor :config, :is_drink, :is_premium_item

  validates_presence_of :name, :menu_item_category, :venue

end
