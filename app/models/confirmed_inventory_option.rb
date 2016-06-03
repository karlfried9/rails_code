class ConfirmedInventoryOption < ActiveRecord::Base
  self.table_name = :confirmed_options

  store_accessor :selection

  store_accessor :data, :parkingAllocated
  store_accessor :data, :parkingTicketsSent
  store_accessor :data, :oysterSpecial

  acts_as_paranoid

  belongs_to :inventory
  belongs_to :client

  has_one :facility, through: :inventory
  has_many :tickets, through: :inventory
  has_one :event_date, through: :inventory
  has_one :event, through: :event_date

  scope :attending, -> {where(is_attending: true)}

  after_create :send_confirmation_email

  def send_confirmation_email
    MailgunMailer.delay(queue: :mailer).option_confirm_notification(self)
  end
end
