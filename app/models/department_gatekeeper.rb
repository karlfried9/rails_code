class DepartmentGatekeeper < ActiveRecord::Base
  belongs_to :department
  belongs_to :employee

  delegate :full_name, to: :employee, prefix: true, allow_nil: true
  delegate :name, to: :department, prefix: true, allow_nil: true

end