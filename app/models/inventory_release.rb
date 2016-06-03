class InventoryRelease < ActiveRecord::Base
  has_closure_tree

  belongs_to  :department
  belongs_to  :client
  belongs_to  :inventory
  belongs_to  :venue
  has_many    :request_attendances, dependent: :destroy

  has_many :available_request_attendances, -> (object){ where("attendee_type is null AND approval_status != 'cancelled'")},  :class_name => 'RequestAttendance'

  validate :count_doesnt_exceed_totals?, unless: :skip_totals_validation
  validate :counts_arent_less_than_child_counts?
  validate :children_already_exist, on: :create

  def children_already_exist

    dep_ids = department.self_and_descendants.map(&:id)
    if dep_ids
      if InventoryRelease.where(inventory_id: inventory_id, department_id: dep_ids).count > 0
        errors.add :base, "You have to split from the top down"
      end
    end
  end

  def count_doesnt_exceed_totals?
    if parent_id.nil?
      if total_released_count - (total_released_count_was || 0) > (inventory.total - inventory.total_allocated_count)
        errors.add(:base, "Can't allocate more than exists")
      end
    else
      if total_released_count > parent.total_available_count
        errors.add(:base, "Can't allocate more than exists in parent")
      end
    end
  end

  def counts_arent_less_than_child_counts?
    children_total_released_count = children.map(&:total_released_count).reduce(:+) || 0
    if total_released_count < children_total_released_count
      errors.add(:base, "Can't allocate less than exists in children")
    end
  end
  #
  #
  after_commit :update_counts, on: [:create, :update, :destroy]
  after_destroy :update_counts

  # # raw sql
  def update_counts

    self_and_ancestors.each do |release|

      approved_total = release.request_attendances.approved.count
      child_released_count = release.children.map(&:total_released_count).reduce(:+) || 0
      open_total = release.total_released_count - approved_total - child_released_count

      release.update_columns(
        :total_open_count => open_total,
        :total_approved_count => approved_total
      )

    end

    if parent_id.nil?
      inventory_total_released_count = InventoryRelease.where(parent_id: nil, inventory_id: inventory_id).sum(:total_released_count)
      inventory.update_attribute :total_allocated_count, inventory_total_released_count
    end


  end

  before_create do
    write_attribute :venue_id, inventory.venue_id
    write_attribute :total_open_count, total_released_count
  end

  store_accessor :data, :nominations_end_date, :nominations_open_date,
                 :transferred_to_department_id

  counter_culture :inventory

  attr_accessor :skip_totals_validation

  validates :total_released_count, presence: true
  validates_numericality_of :total_released_count, greater_than: 0
  validates_numericality_of :total_approved_count, less_than_or_equal_to: :total_released_count

  delegate :name, to: :department, prefix: true, allow_nil: true
  delegate :department_name, to: :parent, prefix: true, allow_nil: true

  delegate :display_order, to: :department, prefix: true, allow_nil: true
  delegate :parent_id, to: :department, prefix: true, allow_nil: true
  delegate :friendly_name, to: :venue, prefix: true, allow_nil: true


  delegate :host_brief, to: :inventory, allow_nil: true, prefix: true
  delegate :inclusions, to: :inventory, allow_nil: true, prefix: true
  delegate :guest_nomination_notes, to: :inventory, allow_nil: true, prefix: true

  delegate :event_name, to: :inventory, allow_nil: true
  delegate :event_type, to: :inventory, allow_nil: true
  delegate :event_id,   to: :inventory, allow_nil: true
  delegate :allocations_require_approval,   to: :inventory
  delegate :ticket_type, to: :inventory, allow_nil: true, prefix: true
  delegate :event_date_start, to: :inventory
  delegate :event_date_finish, to: :inventory

  %w(total_requested_count total_open_count total_released_count total_approved_count).each do |key|
    scope "#{key}_less_than",                 -> (amount) { where(arel_table[key].lt(amount)) }
    scope "#{key}_less_than_or_equal_to",     -> (amount) { where(arel_table[key].lte(amount)) }
    scope "#{key}_greater_than",              -> (amount) { where(arel_table[key].gt(amount)) }
    scope "#{key}_greater_than_or_equal_to",  -> (amount) { where(arel_table[key].gte(amount)) }
  end



  # Direct allocation to employee
  def allocate_to_employee(employee_id, count)
    records = []
    count.times do
      records << { approval_status: 'approved', inventory_release_id: id, requester_id: employee_id }
    end
    RequestAttendance.create!(records)
  end

=begin
  quantity = amount to take from inventory_release
  type = 'direct_allocation','guest_nomination','employee_request'
  department_id = if we are going to transfer this to another department as well
=end
  def perform_split(quantity, type, approval_path_id = nil)
    return false if (quantity > total_open_count) or (quantity === 0)

    split_type = type.present? ? type : inventory_release_type

    new_attributes = {
        :inventory_release_type => split_type,
        :skip_totals_validation => true,
        :approval_path_id => approval_path_id
    }

    original_released_count = total_released_count

    #  dont make me resort to raw sql....
    ActiveRecord::Base.transaction do
      if quantity != total_open_count
        new_attributes[:total_released_count] = quantity
        new_release = self.dup
        if update_attributes!( :total_released_count => original_released_count - quantity, :skip_totals_validation => true)
          if new_release.update_attributes! new_attributes
            true
          else
            update_attribute!(:total_released_count, original_released_count)
          end
        end
      else
        update_attributes! new_attributes
      end
    end
  end

  def create_request_attendances(quantity, data)
    attendances = []
    data[:inventory_release_id] = id

    quantity.times do |q|
      attendances << RequestAttendance.new(data)
    end


    ActiveRecord::Base.transaction do
      attendances.each(&:save!)
    end

  end

  def transfer_to_department(transfer_department_id)
    transfer_department_id = transfer_department_id.presence ? transfer_department_id : department_id
    # this is a transfer, so we create a record, then 'archive' it.
    # i.e if we giving 5 to someone else we create a new release, set status to transferred, deduct count from
    # the current release and save both
    if transfer_department_id != department_id
      transferred_record = self.clone
      transferred_record.status = 'transferred'
      transferred_record.total_released_count = quantity

      self.transferred_to_department_id = transfer_department_id
      self.total_released_count = total_released_count - transferred_record.total_released_count
      transferred_record.save!
      self.save!
    end
  end

  def total_available_count
    total_released_count - total_approved_count
  end
  #
  # def total_open_count=(foo)
  #
  # end

  def revoke(quantity)
    if quantity == total_released_count
      parent_copy = parent
      if destroy
        parent_copy.update_counts if parent_copy
        true
      else
        errors
      end
    else
      update_attribute :total_released_count, total_released_count - quantity
    end
  end


  def self.fix_counts

  end

  def send_tickets_allocated_confirmation(base_url)
    allocated_count = total_released_count
    department.gatekeepers.each do |gatekeeper|
      token = gatekeeper.reset_password_token
      MailgunMailer.delay.tickets_allocated_confirmation(
        gatekeeper,
        self,
        total_released_count,
        token,
        base_url
      )
    end
  end

end