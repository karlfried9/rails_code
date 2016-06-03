class JobDescription < ActiveRecord::Base
  belongs_to :company, inverse_of: :job_descriptions
  validates_presence_of :title


end