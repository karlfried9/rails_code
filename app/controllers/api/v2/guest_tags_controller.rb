class Api::V2::GuestTagsController < Api::V2::ApplicationController
  def index
    guest_ids = Guest.accessible_by(current_ability).pluck(:id)
    @tags = ActsAsTaggableOn::Tagging.where(taggable_type: 'Guest', taggable_id: guest_ids).includes(:tag).map(&:tag).uniq

  end
end