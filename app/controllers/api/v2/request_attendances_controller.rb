class Api::V2::RequestAttendancesController < Api::V2::ApplicationController
	include ActionController::MimeResponds

	skip_before_filter :authenticate_user, if: -> { request.format.to_sym === :xlsx }
	before_filter :set_current_user, only: :index, if: -> { request.format.to_sym == :xlsx }

	# TODO completely refactor this controller as well, messy as hell.

	before_action :get_requests, only: [:send_invite, :send_survey, :send_confirmation]

	load_and_authorize_resource except: [:send_invite, :send_confirmation, :send_survey]

	def index
		# @request_attendances.where!(released_inventory_request_id: params[:released_inventory_request_id]) if params[:released_inventory_request_id]
		@request_attendances.merge!(RequestAttendance.for_inventory(params[:inventory_id])) if params[:inventory_id]
		
		@request_attendances.where! inventory_release_id: params[:inventory_release_id] if params[:inventory_release_id]
		@request_attendances.where! inventory_release_id: params[:inventory_release_ids].split(',') if params[:inventory_release_ids]

		approval_status = params[:approval_status].split ',' if params[:approval_status]
		@request_attendances.where! approval_status: approval_status if approval_status

		@fields = params[:fields].split ',' if params[:fields]

		# TODO rewrite relationships in model to allow eager loading of attendee, getting slow.
		@request_attendances.includes! requester: [:profile]
		 
		if request.format.to_sym == :xlsx
			@guests = []
			@inventory = Inventory.find(params[:inventory_id])
			RequestAttendance.where(attendee_type: ['Guest', 'Employee'], inventory_id: params[:inventory_id]).where.not(attendee_id: nil).map {|a| @guests << a }
			@guests.sort_by! {|a| a.attendee_last_name }
		end
		respond_to do |format|
			format.json { render }
			format.xlsx
		end

	end

	def download_guests
		if request.format.to_sym == :xlsx
			@data = []
			#@inventories = []
			@inventories = Inventory.where(:id => params[:ids]).sort_by { |a| a.event_date_start }
			#params[:ids].each_with_index do |id, index|
			@inventories.each_with_index do |inventory, index|
				#@inventories[index] = Inventory.find(id)
				@data[index] = []
				RequestAttendance.where(attendee_type: ['Guest', 'Employee'], inventory_id: inventory.id).where.not(attendee_id: nil).map {|a| @data[index] << a }
				@data[index].sort_by! {|a| a.attendee_last_name }
			end      
		end
		respond_to do |format|
			format.xlsx
		end
	end

	def show
	end

	def approve
		if @request_attendance.approve_by(current_user.id)
			render 'show', status: :accepted
		else
			render json: {__errors: @request_attendance.errors}, status: :unprocessable_entity
		end
	end

	def convert_to_guest_partner
		# no funny business
		return head :unprocessable_entity if request_attendance_params[:partner_with].blank?

		@request_attendance.attendee = GuestPartner.new company_id: current_user.company_id
		@request_attendance.partner_with = request_attendance_params[:partner_with]

		if @request_attendance.save
			head :no_content
		else
			render_errors @request_attendance.errors
		end
	end

	#TODO make more DRY
	def cancel
		reissue_ticket = params[:reissue] == 'true' ? true : false

		if reissue_ticket
			if @request_attendance.cancel_and_reissue
				head :no_content
			else
				render json: {}, status: :unprocessable_entity
			end
		else
			if @request_attendance.update_attribute :approval_status, 'cancelled'
				head :no_content
			else
				render json: {}, status: :unprocessable_entity
			end
		end

	end

	def create
		respond_to_create @request_attendance
	end

	def update
		respond_to_update @request_attendance, request_attendance_params
	end

	# TODO Refactor, move invite sent changing to mailer once it is actually sent.
	# most of this is also kinda un-needed, move the logic into the model. so you can reuse it elsewhere.
	# break it out into its own controller or service, as its really to do with notifications.
	def send_invite

		errors = []
		template_id = params[:template_id]

		@request_attendances.each do |request_attendance|
			if request_attendance.next_approver_id.eql?(nil) && request_attendance.approval_status.eql?('approved')
				if request_attendance.attendee
					if request_attendance.attendee_type == 'Guest' && request_attendance.attendee.local_communication_status == 'optout'
						errors << "#{request_attendance.attendee.first_name} #{request_attendance.attendee.last_name} opted out."
					else
						options = build_notificiation_data(request_attendance, template_id)

						# insert invitation track url for tracking email opened
						options['invite_url'] = request.protocol + request.host_with_port + "/api/v2/external/tracking/invite/#{request_attendance.id}.png"

						TelstraMailer.delay.rsvp_email(current_user.email, options)

						request_attendance.invite_sent = true
						request_attendance.has_parking_offered = params[:email_signature][request_attendance.id][:has_parking_offered]

						errors << request_attendance.errors.full_messages.to_sentence unless request_attendance.save
					end
				else
					errors << "#{request_attendance.attendee.first_name} #{request_attendance.attendee.last_name}'s data is pending."
				end
			else
				errors << "Request for #{request_attendance.attendee.first_name} #{request_attendance.attendee.last_name} is still not approved."
			end
		end

		if errors.size > 0
			render json: { message: errors.to_sentence }, status: :unprocessable_entity
		else
			render json: { message: 'Invites sent successfully' }, status: :ok
		end
	end

	def preview_invite_email
		template_id = params[:template_id]
		request = RequestAttendance.find(params[:request_ids])
		options = build_notificiation_data(request[0], template_id)

		@mail_template = MailTemplate.find(options['mail_template_id']).reload
		@subject = Liquid::Template.parse(@mail_template.subject).render(options)

		@attendee_id = options['recipient_id']
		@action_name = options['action_name']

		if options['template_body']
			@template = Liquid::Template.parse(options['template_body']).render(options)
		else
			@template = Liquid::Template.parse(@mail_template.body).render(options)
		end
		@reply_to = Liquid::Template.parse(@mail_template.reply_to).render(options)

		respond_to do |format|
			format.json { render json: {content: @template, subject: @subject, reply_to: @reply_to} }

			format.pdf {
				headers['Content-Transfer-Encoding'] = 'binary'
				headers['Content-Type'] = 'arraybuffer'
				page_zoom = params[:page_zoom]
				page_size = params[:page_size]


				kit = PDFKit.new(
						@template, :zoom => page_zoom,
						:page_size => page_size,
						:margin_left => 0, :margin_right => 0,
						:margin_top => 2, :margin_bottom => 0
				)
				send_data(kit.to_pdf, :filename => 'report.pdf', :type => 'application/pdf', :disposition => 'inline')
			}
		end

	end


	def send_confirmation

		errors = []
		template_id = params[:template_id]
		@request_attendances.each do |request|
			#TODO is the approval status for this "approved" ?
			if request.next_approver_id.eql?(nil) && request.approval_status.eql?('approved')
				if request.attendee
					options = build_notificiation_data(request, template_id)

					#TODO rename the mailer method to be more meaningful and reusable
					TelstraMailer.delay.rsvp_email(current_user.email, options)

					request.invite_sent = true
					errors << request.errors.full_messages.to_sentence unless request.save
				else
					errors << "#{request.attendee.first_name} #{request.attendee.last_name}'s data is pending."
				end
			else
				errors << "Request for #{request.attendee.first_name} #{request.attendee.last_name} is still not approved."
			end
		end

		if errors.size > 0
			render json: { message: errors.to_sentence }, status: :unprocessable_entity
		else
			render json: { message: 'Confirmation email sent successfully' }, status: :ok
		end
	end

	def send_survey
		sent_array = []

		if params[:id]
			@request_attendance = RequestAttendance.find params[:id]
			sent_array << _send_survey_single(@request_attendance)

		elsif params[:multiple_ids]
			@request_attendances = RequestAttendance.where id: params[:multiple_ids]

			@request_attendances.each do |request|
				sent_array << _send_survey_single(request)
			end

		else
			return head :not_implemented
		end

		head :no_content

	end

	def send_rsvp_confirmation
		options = build_confirmation_notificiation_data(@request_attendance)

    if TelstraMailer.delay.rsvp_reply_email(options)
			head :no_content
		else
			head :unprocessable_entity
		end

	end

	private
	# TODO check if we actually need to have released inventoryrrequest id in here, seems stupid to me
	def request_attendance_params
		params.require(:request_attendance).permit(
				:released_inventory_request_id,
				:is_coming, :notes, :is_host, :approval_status, :survey_allowed,
				:attendee_type, :attendee_id, :has_attended, :rsvp_completed, :mobile_number,
				:partner_with, :ticket_number, :attendee_first_name, :attendee_last_name, :attendee_mobile_number, :has_parking_offered,
        :is_marked_as_wastage, :attached_ticket, :delete_attached_ticket,
				:rsvp_answers => [:is_parking_required, :parking_requirements_special, :selected_diet, :diet_description]
		)
	end

	def get_requests
		@request_attendances = RequestAttendance.where('id in (?)', params[:request_ids])
	end

	def _send_survey_single(request_attendance)
		if request_attendance.update_attribute(:survey_sent, true)
			TelstraMailer.delay.survey_email(current_user.email, request_attendance, request.base_url)
			true
		else
			false
		end
	end

	# Don't like setting cookies site wide. really lazy.
	def set_current_user
		render nothing: true, status: :unauthorized unless AuthenticationToken.valid?(cookies[:token])
		payload = AuthenticationToken.valid?(cookies[:token]).first
		current_user = Employee.find(payload['user_id'])
		current_user
	end


	# TODO lets copy more messy shit!
	def build_confirmation_notificiation_data(request)
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
		attached_ticket_urls.delete("")

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


	# TODO refactor this, its messy shit.
	def build_notificiation_data(request, template_id)
		args = request.email_arguments
		recipient = request.attendee
		requester = current_user
		dates = args[:date].event_period
		event_dates = "#{dates.first.strftime("%A %e %B %Y")}"
		attached_ticket_urls = request.partners.map {|p| p.attached_ticket.try(:to_s)}
		attached_ticket_urls.push(request.attached_ticket.to_s) if request.attached_ticket
		attached_ticket_urls.delete("")
		data = {
			'event_name' => request.inventory.event_name || args[:event].name,
			'venue_name' => args[:event].venue.name,
			'event_dates' => Time.at(request.inventory.event_date_start).strftime("%A %e %B %Y") || event_dates,
			'company_address_url' => args[:event].venue.address["address2"],
			'recipient_id' => request.id,
			'has_partners' => request.partners.present?,
			'event_child_friendly' => request.inventory.is_child_friendly,
			'partners_count' => request.partners.count.to_words,
			'partners_count_int' => request.partners.count,
			'ticket_type' => request.inventory.ticket_type.humanize,
			'attached_tickets' => attached_ticket_urls,
			'rep_email' => params[:email_signature][request.id][:rep_email] || recipient.try(:rep_email),
			'reply_to' => params[:email_signature][request.id][:template_reply_to],
			'recipient' => {'first_name' => ::ActiveSupport::Inflector.titleize(recipient.first_name), 'last_name' => recipient.last_name, 'email' => recipient.email, 'title' => recipient.title, 'postnominal' => recipient.postnominal},
			'requester' => {
												'sign_off' => params[:email_signature][request.id][:sign_off] || '',
												'full_name' => params[:email_signature][request.id][:full_name] || requester.try(:full_name),
												'email' => requester.email,
												'phone' => params[:email_signature][request.id][:phone] || requester.try(:mobile_number),
												'department_name' => params[:email_signature][request.id][:department_name] || requester.department.formal_name || requester.department_name,
												'designation' => params[:email_signature][request.id][:designation] || requester.try(:position),
												'first_name' => requester.first_name
											},
			'mail_template_id' => template_id,
      'request_attendance_id' => request.id,
			'action_name' => action_name,
			'template_body' => params[:email_signature][request.id][:template_body],
			'template_subject' => params[:email_signature][request.id][:template_subject]
		}


		if params[:email_signature][request.id][:rsvp_by_date]
			data['rsvp_by_date'] = DateTime.parse(params[:email_signature][request.id][:rsvp_by_date]).strftime("%d/%m/%Y")
		end



		data
	end

end
