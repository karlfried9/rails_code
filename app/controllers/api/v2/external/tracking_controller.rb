class Api::V2::External::TrackingController < Api::V2::External::ApplicationController
  before_filter :load_request_attendance, only: [:invite, :survey]


  def invite
    @request_attendance.update_attribute :invite_opened, true

    send_file "#{Rails.root}/public/images/blank.png",
              type: 'image/png', disposition: 'inline',
              filename: params[:filename] + '.png'
  end

  def survey
    @request_attendance.update_attribute :survey_opened, true

    send_file "#{Rails.root}/public/images/blank.png",
              type: 'image/png', disposition: 'inline',
              filename: params[:filename] + '.png'
  end

  private

  def load_request_attendance
    request_attendance_id = params[:filename].split('_')[0]

    begin
      @request_attendance = RequestAttendance.find request_attendance_id
    rescue Exception => e
      head :not_found
    end

  end
end
