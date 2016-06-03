class Api::V2::ApplicationController < ApplicationController
  include ActionController::ImplicitRender

  rescue_from CanCan::AccessDenied do |exception|
    render json: {message: exception.message}, status: :forbidden
  end


  # DRY up the controllers
  def respond_to_update(resource, params)
    if resource.update_attributes params
      render 'show'
    else
      render_errors resource.errors
    end
  end

  def respond_to_create(resource)
    if resource.save
      render 'show', status: :created
    else
      render_errors resource.errors
    end
  end

  def render_errors(errors, status = :unprocessable_entity)
    render json: {__errors: errors}, status: :unprocessable_entity
  end

end