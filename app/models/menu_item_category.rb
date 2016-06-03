class MenuItemCategory < ActiveRecord::Base
  belongs_to :venue
  has_many :menu_items

  validates_presence_of :name
end
