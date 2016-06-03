module RequestAttendanceDelegates
  extend ActiveSupport::Concern

  included do
    delegate :full_name,      to: :requester, prefix: true
    delegate :full_name,      to: :attendee, prefix: true, allow_nil: true
    delegate :company_name,   to: :attendee, prefix: true, allow_nil: true
    delegate :email,          to: :attendee, prefix: true, allow_nil: true
    delegate :job_title,      to: :attendee, prefix: true, allow_nil: true
    delegate :first_name,     to: :attendee, prefix: true, allow_nil: true
    delegate :last_name,      to: :attendee, prefix: true, allow_nil: true
    delegate :mobile_number,  to: :attendee, prefix: true, allow_nil: true
    delegate :rep_email,      to: :attendee, prefix: true, allow_nil: true
    delegate :event_date_start, to: :inventory_release
    delegate :event_date_finish, to: :inventory_release
    delegate :event_name, to: :inventory_release
    delegate :department_name, to: :inventory_release
  end

end