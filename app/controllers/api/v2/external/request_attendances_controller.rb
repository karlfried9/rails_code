class Api::V2::External::RequestAttendancesController < Api::V2::External::ApplicationController
  before_filter :load_request_attendance

  def show
    # TODO implement survey stuff
    # Maybe this is all a bit blah? maybe I should just return the payload anyway
    # and then let the consumer figure out what to show with it. wqill/might make alot more sense as well
    # error wise, not just a 410?

    if params[:type] === 'rsvp'
      if @request_attendance.rsvp_completed
        return head :gone
      end
    elsif params[:type] === 'survey'
      if @request_attendance.survey_completed
        return head :gone
      end

      if @request_attendance.has_attended === false
        return head :not_found
      end

      if @request_attendance.survey_allowed === false
        return head :forbidden
      end

    else
      return head :gone
    end

  end

  def rsvp_results

  end

  def calendar_for_event
    @calendar = @request_attendance.generate_ics_file
    send_data @calendar.to_ical, filename: "#{@request_attendance.event_name}.ics", content_type: 'text/calendar', disposition: :download
  end

  def update
    if respond_to_update @request_attendance, request_attendance_params

      # why are we sending confirmation more than one time??
      options = build_notificiation_data(@request_attendance)
      TelstraMailer.delay.rsvp_reply_email(options)
      #if @request_attendance.is_coming
      @request_attendance.update(:invite_opened => true, :confirmation_sent => true)
      #end
    end
  end

  # :partner_atttending, :partner_first_name, :partner_last_name, :partner_id
  private

  def load_request_attendance
    @request_attendance = RequestAttendance.approved.find(params[:id])
  end

  def request_attendance_params
    params.require(:request_attendance).permit(
        :is_coming, :mobile_number, :rsvp_completed, :survey_allowed, :survey_completed, :is_partners_coming,
        partners_attributes: [ :id, :rsvp_completed, :is_coming, :attendee_first_name, :attendee_last_name, :attendee_mobile_number]).tap do |whitelisted|
        whitelisted[:rsvp_answers] = params[:request_attendance][:rsvp_answers]
        whitelisted[:survey_answers] = params[:request_attendance][:survey_answers]
    end
  end

  def build_notificiation_data(request)
    args = request.email_arguments
    recipient = request.attendee
    requester = request.requester
    dates = args[:date].event_period
    event_dates = "#{dates.first.strftime("%A %e %B %Y")}"
    is_coming = request.is_coming

    senior_gatekeeper_id = request.inventory.client.company_config.senior_gatekeeper

    senior_gatekeeper = requester
    if senior_gatekeeper_id
      senior_gatekeeper = request.inventory.client.employees.find(senior_gatekeeper_id)
    end

    mail_template_id = request.inventory.confirm_mail_template
    if mail_template_id.nil? || mail_template_id == ""
      mail_template_id = request.inventory.client.company_config.default_confirmation_template
    end

    attached_ticket_urls = request.partners.map {|p| p.attached_ticket.try(:to_s)}
    attached_ticket_urls.push(request.attached_ticket.to_s) if request.attached_ticket

    data = {
      'mail_template_id' => mail_template_id,
      'event_name' => request.inventory.event_name || args[:event].name,
      'venue_name' => args[:event].venue.name,
      'event_dates' => Time.at(request.inventory.event_date_start).strftime("%A %e %B %Y") || event_dates,
      'company_address_url' => args[:event].venue.address["address2"],
      'recipient_id' => request.id,
      'has_partners' => request.partners.present?,
      'event_child_friendly' => request.inventory.is_child_friendly,
      'ticket_type' => request.inventory.ticket_type.humanize,
      'recipient' => {'first_name' => ::ActiveSupport::Inflector.titleize(recipient.first_name), 'email' => recipient.email},
      'attendee' => request.attendee,
      'is_coming' => request.is_coming,
      'attached_tickets' => attached_ticket_urls,
      'senior_gatekeeper' => {
        'sign_off' => senior_gatekeeper.first_name,
        'full_name' => senior_gatekeeper.try(:full_name),
        'email' => senior_gatekeeper.email,
        'first_name' => senior_gatekeeper.first_name
      },
    }

    data
  end
end