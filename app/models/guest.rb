class Guest < ActiveRecord::Base
  include PgSearch
  # multisearchable :against => [:first_name, :last_name, :email]

  acts_as_taggable

  belongs_to :company
  has_many :request_attendances, as: :attendee
  belongs_to :department
  accepts_nested_attributes_for :tags

  store_accessor :data, :direct_number, :mobile_number, :company, :position, :revenue, :crm_link, :job_title, :job_band, :relevance, :contact_id, :sex,
                 :execdir_name, :salesdir_name, :rep_name, :gm_name, :rep_email, :crm_1, :crm_2, :tier, :street_address, :suburb, :postcode, :state, :customer_segment,
                 :crm_communication_status, :local_communication_status, :imported_from_crm, :courtesy_title, :title, :postnominal, :personal, :address_with_formal_titles


  attr_accessor :tag_names

  pg_search_scope :search, :against => {
                             first_name: 'B',
                             last_name: 'A',
                             email: 'C',
                             search_index: 'D'

                         },
                  :using => {
                      tsearch: {prefix: true},
                      # trigram: {}
                      # dmetaphone: {}
                  }

  #
  #
  # def self.multisearch(terms)
  #     split_terms = terms.split(' ')
  #
  #     search(terms).where("search_index ILIKE ?","%#{terms}%")
  #
  #     # split_terms.each do |term|
  #     #   chain = chain.or.where(arel_table[:search_index].matches("%#{term}%"))
  #     # end
  #
  #   # where id: PgSearch::Document.where(searchable_type: 'Guest').pluck(:searchable_id)
  # end

  def self.rebuild_search_index
    # WITH content_to_use AS (
    #   SELECT
    #     replace(
    #       replace(
    #         replace(
    #             (lower(first_name) || ' ' || lower(last_name) || ' ' || lower(email) || ' ' || '$company_name$' || ' tag:"$tag_names$"'),
    #          '$company_name$', replace(replace(replace(lower(guests.data->>'company'), '&', ''),'(',''), ')', '')
    #         ),
    #        '$tag_names$', lower(array_to_string(array_agg(DISTINCT tags.name), '" tag:"'))
    #       ), 'tag:""', ''
    #     ) AS content, guests.id AS guest_id from guests
    #       LEFT JOIN taggings ON taggings.taggable_id = guests.id
    #       LEFT JOIN tags on taggings.tag_id = tags.id
    #       GROUP BY guests.id
    # )
    # WITH content_to_use AS (
    #                            SELECT
    # replace(
    #     replace(
    #         replace(
    #             ('$company_name$' || ' tag:"$tag_names$"'),
    #             '$company_name$', replace(replace(replace(lower(guests.data->>'company'), '&', ''),'(',''), ')', '')
    #         ),
    #         '$tag_names$', lower(array_to_string(array_agg(DISTINCT tags.name), '" tag:"'))
    #     ), 'tag:""', ''
    # ) AS content, guests.id AS guest_id from guests
    # LEFT JOIN taggings ON taggings.taggable_id = guests.id
    # LEFT JOIN tags on taggings.tag_id = tags.id
    # GROUP BY guests.id
    # )
    connection.execute <<-SQL
      WITH content_to_use AS (
        SELECT id AS guest_id,
          replace(replace(replace(lower(guests.data->>'company'), '&', ''),'(',''), ')', '') AS company,
          lower(guests.data->>'job_band') AS job_band
        FROM guests
      )

      UPDATE guests SET search_index = (content_to_use.company || ' ' || content_to_use.job_band) FROM content_to_use WHERE guests.id = content_to_use.guest_id

    SQL
  end

  scope :search_by_email, ->(email) { ActiveRecord::Base.connection.execute("SELECT set_limit(0.1);"); where("email ILIKE '%#{email}%'") }
  scope :search_by_first_name, ->(first_name) { where("first_name ILIKE '%#{first_name}%'") }
  scope :search_by_last_name, ->(last_name) { where("last_name ILIKE '%#{last_name}%'") }
  scope :search_by_position, ->(position) { where("CAST(data -> 'position' AS text) ILIKE '%#{position}%'") }
  scope :search_by_company, ->(company) { where("CAST(data -> 'company' AS text) ILIKE '%#{company}%'") }
  scope :search_by_title, ->(title) { where("CAST(data -> 'title' AS text) ILIKE '%#{title}%'") }
  scope :search_by_postnominal, ->(postnominal) { where("CAST(data -> 'postnominal' AS text) ILIKE '%#{postnominal}%'") }
  scope :search_by_name, ->(name) { where("first_name ILIKE ? OR last_name ILIKE ?", "%#{name}%","%#{name}%") }
  # scope :search, -> (terms) do
  #   where "first_name ILIKE ? OR last_name ILIKE ? OR email ILIKE ? OR CAST(data -> 'company' AS text) ILIKE ?", "%#{terms}%","%#{terms}%","%#{terms}%","%#{terms}%"
  # end

  # this is pretty insane
  # def self.rebuild_pg_search_documents
  #   connection.execute <<-SQL
  #    INSERT INTO pg_search_documents (searchable_type, searchable_id, content, created_at, updated_at)
  #     SELECT 'Guest' AS searchable_type, guests.id AS searchable_id,
  #     replace(
  #       replace(
  #           replace(
  #               (lower(first_name) || ' ' || lower(last_name) || ' ' || lower(email) || ' ' || '$company_name$' || ' tag:"$tag_names$"'),
  #            '$company_name$', replace(replace(replace(lower(guests.data->>'company'), '&', ''),'(',''), ')', '')
  #           ),
  #        '$tag_names$', lower(array_to_string(array_agg(DISTINCT tags.name), '" tag:"'))
  #       ), 'tag:""', ''
  #     ) AS content,
  #       now() AS created_at,
  #       now() AS updated_at
  #       FROM guests
  #       LEFT JOIN taggings ON taggings.taggable_id = guests.id
  #       LEFT JOIN tags on taggings.tag_id = tags.id
  #
  #       GROUP BY guests.id
  #   SQL
  # end

  # SELECT 'Guest' AS searchable_type,
  #                   guests.id AS searchable_id,
  #                                (guests.name || ' ' || directors.name) AS content,
    #guest
  def company_name
    company
  end

  def communication_status
    local_communication_status.nil? || local_communication_status=='unknown' ? crm_communication_status : local_communication_status
  end


  # def crm_communication_status
  #   return 'unknown' if data[:crm_communication_status].nil?
  #   data[:crm_communication_status]
  # end


  def self.search_by_tag(tag_name)
    Guest.tagged_with(tag_name)
  end

  def full_name
    [first_name, last_name].join ' '
  end

  def available_tags
    Guest.tag_counts_on :tags
  end

  before_save :humanize_data

  def humanize_data
    # first_name.try :capitalize!
    # last_name.try :capitalize!
    email.try :downcase!
    # suburb.try :capitalize!
    # state.try :upcase!
    # company.try :capitalize!
    # street_address.try :downcase!
  end

end
