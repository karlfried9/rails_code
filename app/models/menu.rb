class Menu < ActiveRecord::Base
  include MultiplePrices

  # audited
  belongs_to  :venue

  has_many :confirmable_flow_items, as: :confirmable_flow_item

  has_many    :menu_sections

  store_accessor :config, :has_drinks_package
  store_accessor :data, :choices

  validates_presence_of :name, :internal_name

  validates_presence_of :price_level_0, if: -> { menu_type == 'food'}

  accepts_nested_attributes_for :menu_sections, allow_destroy: true
end
