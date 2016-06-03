class Api::V2::SessionsController < Api::V2::ApplicationController

  skip_filter :authenticate_user, only: :create

  def index
    @employee = current_user
    render 'api/v2/employees/show'
  end

  def create
    if params[:email]
      @employee = Employee.find_by_email params[:email].downcase

      # Validate that the user has been found and that the password is valid
      # This is shit. why have we got like 100 nested ifs.
      if @employee
        if @employee.password_digest
          if @employee.can_login?
            if params[:password]
              if @employee.authenticate(params[:password])
                if @employee.password_reset_date
                  reset_date = @employee.password_reset_date
                else
                  reset_date = @employee.created_at
                end

                if reset_date+6.month > Time.now

                  # Set our token in the header for the program to extract and store
                  response.headers['X-Set-Auth-Token'] = AuthenticationToken.issue_token({:user_id => @employee.id})

                  # Send our response
                  return render 'api/v2/employees/show', status: :created
                else
                  token = @employee.reset_password_token
                  MailgunMailer.delay(queue: :mailer).reset_password_request(token, @employee, {url:request.base_url, ip:request.remote_ip})
                  #MailgunMailer.reset_password_request(token, @employee, {url:request.base_url, ip:request.remote_ip}).deliver
                  return render json: {error_code: 1, message: "Your Password is Expired. Please Check Your Email and Reset Password."}, status: :unprocessable_entity
                end
              else
                return render json: {error_code: 1, message: 'Invalid email or password. If this is your first time use you’ll need to reset your password FIRST - please click Reset Password to do so.'}, status: :forbidden
              end
            end
          else
            return render json: {error_code: 1, message: "You can't login"}, status: :forbidden
          end
        else
          token = @employee.reset_password_token
          MailgunMailer.delay(queue: :mailer).reset_password_request(token, @employee, {url:request.base_url, ip:request.remote_ip})
          #MailgunMailer.reset_password_request(token, @employee, {url:request.base_url, ip:request.remote_ip}).deliver
          return render json: {error_code:1, message: "We see this is your first login. A reset email has been sent"}, status: :unprocessable_entity
        end
      end
    end

    render json: {error_code: 1, message: 'Email does not exist.'}, status: :unprocessable_entity
  end

  # def create
  #   @user = Employee.find_by(email: params[:email].downcase)
  #   if @user && @user.can_login? && @user.authenticate(params[:password])
  #
  #     if @user.otp_secret
  #       unless params[:totp] && @user.verify_totp(params[:totp])
  #         head :unauthorized
  #         return
  #       end
  #     end
  #
  #     token = SecureRandom.uuid
  #
  #     Rails.cache.write(token, @user, expires_in: 15.hours)
  #
  #     headers['X-Set-Auth-Token'] = token
  #     render json: @user, status: :created
  #   else
  #     head :unauthorized
  #   end
  # end

end