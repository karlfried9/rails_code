class Api::V2::SecurityController < ApplicationController
  skip_before_filter :authenticate_user
  def reset_password
    @employee = Employee.for_password_token(params[:token])
    if params[:password].downcase.include?(@employee.profile.first_name.downcase) || params[:password].downcase.include?(@employee.profile.last_name.downcase)
      render json: {message: "Error: The password chosen must not contain all or part of the user's account name."}, status: :unprocessable_entity
    else
      if @employee.reset_password!(reset_password_params)
        head :ok
      else
        head :bad_request
      end
    end
  end

  def request_password_reset
    @employee = Employee.find_by_email(params[:email].downcase)
    if @employee
      token = @employee.reset_password_token
      MailgunMailer.delay(queue: :mailer).reset_password_request(token, @employee, {url:request.base_url, ip:request.remote_ip})
      #MailgunMailer.reset_password_request(token, @employee, {url:request.base_url, ip:request.remote_ip}).deliver
      return head :created
    end
    return head :unprocessable_entity
  end

  private
    def reset_password_params
      params.permit(:token ,:password, :password_confirmation)
    end
end