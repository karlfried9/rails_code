class Company < ActiveRecord::Base
  # TODO Split this class, STI style. Currently its very messy and unclear as to what is happening

  store_accessor :address, :address1, :address2, :postcode, :suburb, :state, :city
  store_accessor :contact, :phone, :fax
  store_accessor :notifications, :notify_sms, :notify_email
  store_accessor :modules, :guest_module

  delegate :email, to: :manager, prefix: true, allow_nil: true


  has_many :employees, inverse_of: :company
  has_many :departments, inverse_of: :company

  has_many :guests, foreign_key: :company_id
  has_many :job_descriptions, inverse_of: :company

  has_one :company_config
  
  validates_uniqueness_of :name

  belongs_to :manager, class_name: 'Employee'

  def managers
    employees.where("employees.permissions ->> 'client_admin?' = 'true'")
  end

  validates_presence_of :name, :friendly_name
  # validates_format_of :name, :friendly_name, with: /\A[[:alpha:]\s'"\-_&@!?()\[\]-]*\Z/u

  before_validation :set_friendly_name_from_name


  def self.search_with_uuids(uuids)
    self.find(uuids)
  end

  def to_s
    name
  end

  protected
    def set_friendly_name_from_name
      self.friendly_name = self[:name] if self[:name]
    end

end
