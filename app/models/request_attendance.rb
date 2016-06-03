# this class is a freaking mess.
class RequestAttendance < ActiveRecord::Base
  include RequestAttendanceDelegates

  belongs_to :attendee, polymorphic: true, inverse_of: :request_attendances
  belongs_to :released_inventory_request, inverse_of: :request_attendances

  belongs_to :inventory, inverse_of: :request_attendances

  belongs_to :inventory_release, inverse_of: :request_attendances

  belongs_to :requester, class_name: 'Employee'
  belongs_to :parent_guest, class_name: 'RequestAttendance', foreign_key: :partner_with

  has_many :partners, class_name: 'RequestAttendance', foreign_key: :partner_with

  accepts_nested_attributes_for :partners, reject_if: :all_blank
  accepts_nested_attributes_for :attendee

  store_accessor  :data, :invite_sent, :invite_opened, :rsvp_completed, :is_coming,  :is_partners_coming, :has_parking_offered,
                  :notes, :has_attended, :survey_sent, :survey_opened, :survey_completed,
                  :confirmation_sent, :ticket_number, :survey_allowed, :nomination_preference, :nomination_notes,
                  :special_requests, :comments, :strategic_reason, :is_marked_as_wastage,
                  :attached_ticket_file_name, :attached_ticket_file_size, :attached_ticket_content_type, :attached_ticket_updated_at


  has_attached_file :attached_ticket, default_url: ''
  # has to come after attached file definition
  include DeletableAttachment
  validates_attachment :attached_ticket, content_type: { content_type: ['application/pdf'] }


  attr_writer :mobile_number
  attr_writer :attendee_first_name, :attendee_last_name, :attendee_mobile_number

  after_validation :attach_mobile_number
  after_validation :attach_attendee_if_partner, if: Proc.new { |this| this.attendee_type === 'GuestPartner' }

  before_save do
    write_attribute :inventory_id, inventory_release.inventory_id
  end

  # validates do
  #   if
  # end

  # validates_presence_of :released_inventory_request_id
  validates_presence_of :inventory_release_id, :requester_id

  scope :for_inventory, -> (inventory_id) { joins(inventory_release: :inventory).where("inventories.id = ?", inventory_id)}

  scope :pending, -> { where("approval_status = 'pending'") }
  scope :approved, -> { where("approval_status = 'approved'") }
  scope :rejected, -> { where("approval_status = 'rejected'") }
  scope :cancelled, -> { where("approval_status = 'cancelled'") }



  def attach_mobile_number
    if attendee && attendee_type === 'Guest'
      unless @mobile_number.nil? || @mobile_number.empty?
        attendee.update_attribute :mobile_number, @mobile_number
      end
    end

    if attendee && attendee_type === 'Employee'
      unless @mobile_number.nil? || @mobile_number.empty?
        attendee_profile = Profile.find_or_initialize_by employee_id: attendee_id
        attendee_profile.update_attribute :mobile_number, @mobile_number
      end
    end
  end

  def attach_attendee_if_partner
    return unless attendee
    # attendee.first_name = @attendee_first_name
    attendee.attributes = ({first_name: @attendee_first_name, last_name: @attendee_last_name, mobile_number: @attendee_mobile_number})
    attendee.save!
    # attendee.update_attributes first_name: @attendee_first_name, last_name: @attendee_last_name
  end


  def approved?
    approval_status == 'approved'
  end


  counter_culture :inventory_release,
                  column_name: 'total_requested_count'

  after_commit do
    inventory_release.update_counts
  end


  # TODO  this is silly.
  def email_arguments
    event = Event.for_attendance(self.inventory_release_id)
    inventory = Inventory.for_attendance(self.inventory_release_id)
    date = EventDate.for_attendance(inventory.event_date_id)

    { event: event, date: date }
  end

  def is_employee
    attendee_type === 'Employee'
  end

  def generate_ics_file
    calendar = Icalendar::Calendar.new

    #TODO add more data here
    calendar.event do |e|
      e.dtstart = event_date_start
      e.dtend = event_date_finish
      e.summary = "#{event_name}"
      e.location = inventory.venue_friendly_name
    end

    calendar
  end

  def cancel_and_reissue
    return true if approval_status == 'cancelled'
    partners_present = partners.present?

    begin
      ActiveRecord::Base.transaction do
        RequestAttendance.create!(
            inventory_release_id: self.inventory_release_id,
            requester_id: self.requester_id,
            approval_status: 'approved'
        )

        update_attribute(:approval_status, 'cancelled')
        if partners_present
          partners.each do |partner|
            partner.cancel_and_reissue
          end
        end
        true
      end
    rescue
      false
    end
  end

  def approve_by(approver_id)
    #TODO hook in approval path shiz here
    if inventory_release.total_open_count >= 1
      update_attributes(
          approval_status: 'approved',
          last_approver_id: approver_id
      )
    else
      errors[:base] << "No Open Tickets Left"
      false
    end
  end


end