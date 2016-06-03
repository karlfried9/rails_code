class Api::V2::External::ApplicationController < Api::V2::ApplicationController
  skip_before_filter :authenticate_user
end