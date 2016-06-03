class MenuSpecialOption < ActiveRecord::Base
  has_many :menu_sections
  has_many :menus, through: :menu_sections

  store_accessor :data, :modal_choice_text, :menu_section_text
end
