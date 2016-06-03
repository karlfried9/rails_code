module EventUploads
  extend ActiveSupport::Concern

  included do
    store_accessor  :uploads,
                    :tile_file_name, :tile_file_size, :tile_content_type, :tile_updated_at,
                    :agenda_file_name, :agenda_file_size, :agenda_content_type, :agenda_updated_at,
                    :menu_file_name, :menu_file_size, :menu_content_type, :menu_updated_at

    has_attached_file :tile, default_url: ''

    validates_attachment :tile, content_type: { content_type: ['image/jpg', 'image/jpeg', 'image/png'] }

    has_attached_file :agenda, default_url: ''
    validates_attachment :agenda, content_type: { content_type: ['application/pdf'] }

    has_attached_file :menu, default_url: ''
    validates_attachment :menu, content_type: { content_type: ['application/pdf'] }

    include DeletableAttachment
  end
end