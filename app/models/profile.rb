class Profile < ActiveRecord::Base
  belongs_to :employee

  validates_presence_of :first_name, :last_name

  store_accessor :data, :mobile_number

  def full_name
    [first_name,last_name].join ' '
  end

end
