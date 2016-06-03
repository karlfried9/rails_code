class Api::V2::NotificationsController < Api::V2::ApplicationController


  def create
    @event_date = EventDate.includes(:event).find(notification_params[:event_date_id]) if notification_params[:event_date_id]

    @event_dates = @event_date.event.dates.map do |date|
      {
          'event_start' => date.event_period.begin.to_s(:human),
          'unformatted_event_start' => date.event_period.begin,
          'event_finish' => date.event_period.end.to_s(:human),
          'unformatted_event_finish' => date.event_period.end
      }
    end

    if notification_params[:recipient_company_ids]
      recipient_companies = Company.where(id: notification_params[:recipient_company_ids])

      # All managers of the company get the email.
      @companies = recipient_companies.map do |c|
        {
          company_name: c.name,
          managers: c.managers.map do |m|
            {'email' => m.email, 'first_name' => m.first_name, 'last_name' => m.last_name}
          end
        }
      end

      @companies.each do |company|
        company[:managers].each do |manager|
          data = build_notificiation_data company, manager
          MailgunMailer.delay(queue: :mailer).notification_mailer(data)
        end
      end
    end

    # Test notification, pretty self explanatory, but comments in code
    # make it look like I actually have a clue what I am doing.
    if notification_params[:is_test_notification]
      manager = {'email' => current_user.email, 'first_name' => current_user.first_name, 'last_name' => current_user.last_name}
      company = {company_name: current_user.company_name}

      data = build_notificiation_data company, manager
      MailgunMailer.delay(queue: :mailer).notification_mailer(data)
    end

    head :no_content
  end


  private
  def notification_params
    params.permit(:event_date_id, :mail_template_id, :is_test_notification, recipient_company_ids:[])
  end

  def build_notificiation_data(company, recipient)
    {
        'event_name' => @event_date.event_name,
        'event_promoter' => @event_date.event_promoter,
        'event_dates' => @event_dates,
        'event_start' => @event_date.event_period.begin.to_s(:human),
        'unformatted_event_start' => @event_date.event_period.begin,
        'event_finish' => @event_date.event_period.end.to_s(:human),
        'unformatted_event_finish' => @event_date.event_period.end,
        'company_name' => company[:company_name],
        'recipient' => recipient,
        'mail_template_id' => notification_params[:mail_template_id]
    }
  end
end