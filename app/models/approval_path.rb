class ApprovalPath < ActiveRecord::Base
  has_one :employee
  belongs_to :approval_path_ownable, polymorphic: true


  def self.path_contains_only(id)
    where("#{connection.quote_column_name(:path)} = ARRAY[?]#{array_cast(:path)}", id)
  end

  def self.path_contains_any(ids)
    array_has_any(:path, ids)
  end

  store_accessor :data, :name



  # after save callback,
  # see which if isActive has changed on the approvalPath
  # if its changed
  # load department, find currently active ApprovalPath
  # get currentlyActiveApprovalPathId
  # map all stuff that had the old id and update it to have the new approvalpath id
  # profit
  after_save :update_approval_paths_on_is_active_change

  def update_approval_paths_on_is_active_change

  end

end
