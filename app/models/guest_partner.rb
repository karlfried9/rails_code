class GuestPartner < ActiveRecord::Base
  has_many :request_attendances, as: :attendee, inverse_of: :attendee
  belongs_to :company

  store_accessor :data, :first_name, :last_name, :mobile_number, :job_title, :rep_email, :email

  def full_name
    [first_name, last_name].join ' '
  end

  def customer_segment
    ''
  end

  def rep_name
    ''
  end
  
  def company_name
    nil
  end
end