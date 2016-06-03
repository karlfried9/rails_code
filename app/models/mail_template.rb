class MailTemplate < ActiveRecord::Base
  belongs_to :company

  delegate :name, to: :company, prefix: true

  scope :editable, -> {  where(editable: true) }

  store_accessor :data, :subject, :requires, :reply_to, :bcc, :state, :img_url, :mail_type, :cc

  validates_presence_of :body, :subject, :locale, :handler, :format, :path, :name

  validates_uniqueness_of :path

  before_validation :set_path_from_name

  # Important
  after_save do
    MailTemplate::Resolver.instance.clear_cache
  end

  def set_path_from_name
    self.path = "#{company_name.gsub(' ', '').underscore}/#{name.gsub(' ', '').underscore}"
  end

  class Resolver < ActionView::Resolver
    require 'singleton'
    include Singleton

    protected
      def normalize_path(name, prefix)
        prefix.present? ? "#{prefix}/#{name}" : name
      end

      def normalize_array(array)
        array.map(&:to_s)
      end

      def initialize_template(record)
        source = record.body
        identifier = "Mail Template - #{record.id} - #{record.path.inspect}"
        handler = ActionView::Template.registered_template_handler(record.handler)
        details = {
            format: Mime[record.format],
            update_at: record.updated_at,
            virtual_path: virtual_path(record.path, record.partial)
        }
        ActionView::Template.new(source, identifier, handler, details)
      end

      def virtual_path(path, partial)
        return path unless partial
        if index == path.rindex('/')
          path.insert(index + 1, '_')
        else
          "_#{path}"
        end
      end

    def find_templates(name, prefix, partial, details)
      conditions = {
          path: normalize_path(name, prefix),
          locale: normalize_array(details[:locale]).first,
          format: normalize_array(details[:formats]).first,
          handler: normalize_array(details[:handlers]),
          partial: partial || false
      }

      ::MailTemplate.where(conditions).map do |record|
        initialize_template record
      end

    end
  end
end
