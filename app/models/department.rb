class Department < ActiveRecord::Base
  has_closure_tree
  acts_as_paranoid

  belongs_to :company, inverse_of: :departments
  has_many :employees, inverse_of: :department
  has_many :inventory_releases, inverse_of: :department
  has_many :department_gatekeepers, inverse_of: :department
  has_many :gatekeepers, through: :department_gatekeepers, class_name: 'Employee', source: :employee

  has_many :guests, foreign_key: :department_partitioning_id

  has_many :approval_paths, as: :approval_path_ownable

  accepts_nested_attributes_for :approval_paths

  accepts_nested_attributes_for :department_gatekeepers, allow_destroy: true

  store_accessor :data, :percent_allocation, :display_order, :formal_name


  validates_presence_of :name, :company
  validates_numericality_of :percent_allocation, greater_than_or_equal_to: 0, less_than_or_equal_to: 100, allow_nil: true


  def parent_department_name
    parent_id && parent.name
  end

end