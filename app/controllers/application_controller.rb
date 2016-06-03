class ApplicationController < ActionController::API
  include CanCan::ControllerAdditions
  include ActionController::Cookies

  before_filter :authenticate_user
  if defined? NewRelic
    include NewRelic::Agent::Instrumentation::ControllerInstrumentation

    if defined? NewRelic::Agent::Instrumentation::Rails4
      include NewRelic::Agent::Instrumentation::Rails4::Errors
    end
  end

  def current_user
    return false unless AuthenticationToken.valid?(header_auth_token)
    payload = AuthenticationToken.valid?(header_auth_token).first
    logged_in_user = Employee.find(payload['user_id'])

    if request.headers['EH-Masquerading-As']
      masqueraded_user = Employee.find(request.headers['EH-Masquerading-As'])
      return masqueraded_user if logged_in_user.can?(:masquerade, masqueraded_user)
    end

    #TODO I dont like this. if you want a cookie you get it when you need it. not all the time. otherwise I just use cookies instead of tokens...
    cookies[:token] = header_auth_token
    logged_in_user
  end

  protected
  def authenticate_user
    render nothing: true, status: :unauthorized unless AuthenticationToken.valid?(header_auth_token)
  end

  def header_auth_token
    #'Authorization' : 'Bearer <token>'
    request.headers['Authorization'].gsub /Bearer /,'' if request.headers['Authorization']
  end

end
