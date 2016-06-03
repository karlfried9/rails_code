class CompanyConfig < ActiveRecord::Base
  # audited
  belongs_to :company

  store_accessor :data, :senior_gatekeeper, :always_approve, :default_business_unit, :password_regex, :help, :default_confirmation_template
  
  store_accessor :logo, :logos_file_name, :logos_file_size, :logos_content_type, :logos_updated_at

  store_accessor :branding, :brandings_file_name, :brandings_file_size, :brandings_content_type, :brandings_updated_at

  has_attached_file :logos, :default_url => 'item_images/add_picture.png'

  has_attached_file :brandings, :default_url => 'item_images/add_picture.png'

  validates_attachment :logos, content_type: { content_type: ['image/jpg', 'image/jpeg', 'image/png'] }
  validates_attachment :brandings, content_type: { content_type: ['image/jpg', 'image/jpeg', 'image/png'] }
  include DeletableAttachment
end
