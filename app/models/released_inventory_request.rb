class ReleasedInventoryRequest < ActiveRecord::Base

  belongs_to :inventory_release

  has_one :inventory, through: :inventory_release

  before_create :set_inventory_id


  has_many :request_attendances, inverse_of: :released_inventory_request
  belongs_to :requester, class_name: 'Employee'
  belongs_to :last_approver, class_name: 'Employee'
  belongs_to :next_approver, class_name: 'Employee'
  belongs_to :approval_path
  # belongs_to :strategic_reason

  delegate :event_name, to: :inventory, allow_nil: true
  delegate :venue_friendly_name, to: :inventory, allow_nil: true
  delegate :event_type, to: :inventory, allow_nil: true
  delegate :event_id,   to: :inventory, allow_nil: true

  delegate :host_brief, to: :inventory, allow_nil: true, prefix: true
  delegate :inclusions, to: :inventory, allow_nil: true, prefix: true

  delegate :event_date_start, to: :inventory
  delegate :event_date_finish, to: :inventory

  # do these depend on each other? no idea. its late.
  counter_culture :inventory_release, column_name: 'total_requested_count', delta_column: 'total_attendee_count'

  after_save :update_counts_on_release
  #

  store_accessor :data, :comments, :special_requests
  has_many :available_request_attendances, -> (object){ where("attendee_type is null AND approval_status != 'cancelled'")},  :class_name => 'RequestAttendance'
  # Not part of bidding, direct allocation
  def allocate_for_employee(count)
    records = []
    count.times do
      records << { approval_status: 'approved', released_inventory_request_id: id }
    end

    if RequestAttendance.create(records)
      update_attribute(:approved_attendee_count, count)
    end

    update_counts_on_release
  end

  private
  def set_inventory_id
    write_attribute :inventory_id, inventory_release.inventory_id
  end

  def update_counts_on_release
    execute_after_commit do
      # This is a lazy count.
      sql = <<-SQL
        UPDATE inventory_releases
        SET total_open_count = (total_released_count - total_approved_count)
        WHERE inventory_releases.id = '#{inventory_release_id}'
      SQL

      ActiveRecord::Base.connection.execute(sql)
      #
      # # This is a proper count
      # sql = <<-SQL
      #   UPDATE inventory_releases
      #   SET total_open_count = (SELECT total)
      #
      #
      # SQL
    end
  end

end