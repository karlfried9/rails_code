class Employee < ActiveRecord::Base
  #
  # def self.primary_key
  #   :id
  # end

  EMAIL_REGEX = /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i

  belongs_to :company, inverse_of: :employees
  belongs_to :department, inverse_of: :employees


  # belongs_to :approval_path, inverse_of: :employee
  has_many :approval_paths, as: :approval_path_ownable

  has_one :profile, inverse_of: :employee

  accepts_nested_attributes_for :profile

  validates :email, uniqueness:  { case_sensitive: false },
            format: { with: EMAIL_REGEX }


  has_many :request_attendances, as: :attendee

  has_many :released_inventory_requests, foreign_key: :requester_id

  # has_many :approved_requests, class_name: 'ReleasedInventoryRequest', foreign_key: :last_approver_id
  # has_many :awaiting_approval_requests, class_name: 'ReleasedInventoryRequest', foreign_key: :next_approver_id

  # has_many :approved_requests, class_name: 'RequestAttendance', foreign_key: :last_approver_id
  # has_many :awaiting_approval_requests, class_name: 'RequestAttendance', foreign_key: :next_approver_id


  has_many :department_gatekeepers, inverse_of: :employee
  has_many :gatekept_departments, through: :department_gatekeepers, class_name: 'Department'


  accepts_nested_attributes_for :department_gatekeepers, allow_destroy: true

  #TODO deprecated
  store_accessor :permissions, :can_login?, :login_disabled?
  #


  def department_partitioning_point
    department_id && department.self_and_ancestors.find {|d| d.is_partitioning_point === true}
  end

  def department_partitioning_point_id
    department_partitioning_point.try(:id)
  end



  %w[standard_user developer super_admin client_admin venue_admin department_admin].each do |key|
    store_accessor :permissions, key
    define_method("is_#{key}?") do
      permissions && permissions[key]
    end
  end

  store_accessor :config, :state, :position, :cost_center, :bi_access, :internal_id, :gatekeeper_role, :title, :can_use_crm, :job_title

  store_accessor :meta, :failed_login_attempts, :last_failed_login

  # validation for password should be false, because when employee is created password is not set
  has_secure_password validations: false

  delegate :can?, :cannot?, to: :ability

  delegate :first_name, to: :profile, allow_nil: true
  delegate :last_name, to: :profile, allow_nil: true
  delegate :full_name, to: :profile, allow_nil: true
  delegate :mobile_number, to: :profile, allow_nil: true

  delegate :name, to: :company, prefix: true, allow_nil: true
  delegate :name, to: :department, prefix: true, allow_nil: true
  delegate :formal_name, to: :department, prefix: true, allow_nil: true



  scope :for_reminder, -> { joins('INNER JOIN released_inventory_requests ON employees.id = released_inventory_requests.next_approver_id')
                            .where('released_inventory_requests.next_approver_id IS NOT NULL AND (released_inventory_requests.next_reminder_date = CURRENT_DATE OR released_inventory_requests.next_reminder_date IS NULL)')
                            .group('employees.id')
                            .includes(:profile) }


  # # TODO remove
  # def has_ownership_of_departments?
  #   Department.where("owner_id = ? OR (secondary_owner_id = ? AND secondary_owner_active = true)", id, id)
  # end
  # alias_method :owned_departments, :has_ownership_of_departments?


  scope :search, -> (terms) {
      joins(:profile)
      .where("profiles.first_name ILIKE ? OR profiles.last_name ILIKE ?", "%#{terms}%","%#{terms}%")
    }

  class << self
    def verifier_for(purpose)
      @verifiers ||= {}
      @verifiers.fetch(purpose) do |p|
        @verifiers[p] = Rails.application.message_verifier("#{self.name}-#{p.to_s}")
      end
    end

    def for_password_token(token)
      employee_id, timestamp = verifier_for('reset-password').verify(token)
      find(employee_id)
    end

  #   def approval_reminder
  #     employees = Employee.for_reminder
  #
  #     employees.each do |employee|
  #       MailgunMailer.approval_reminder(employee)
  #       requests = ReleasedInventoryRequest.where(next_approver_id: employee.id)
  #
  #       requests.each do |request|
  #         request.next_reminder_date = Date.today + 2.days
  #         request.save!
  #       end
  #     end
  #   end
  end

  def reset_password_token
    verifier = self.class.verifier_for('reset-password') # Unique for each type of messages
    verifier.generate([id, Time.now])
  end

  def reset_password!(params)
    # This raises an exception if the message is modified
    employee_id, timestamp = self.class.verifier_for('reset-password').verify(params[:token])

    if timestamp > 3.days.ago
      self.password = params[:password]
      self.password_confirmation = params[:password_confirmation]
      self.password_reset_date = Time.now
      save!
    else
      # Token expired
      # ...
    end
  end

  def verify_totp(otp)
    return false unless self.otp_secret
    totp = ROTP::TOTP.new(self.otp_secret)
    totp.verify(otp)
  end

  def update_totp_secret
    secret = ROTP::Base32.random_base32
    update_attribute :otp_secret, secret
    secret
  end

  def uri_for_totp_secret
    totp = ROTP::TOTP.new(otp_secret)
    totp.provisioning_uri(email)
  end

  def ability
    @ability ||= Ability.new(self)
  end



  def customer_segment
    ''
  end

  def rep_name
    ''
  end

  def postnominal
    ''
  end



end
