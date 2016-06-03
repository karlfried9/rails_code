class Api::V2::AttendeesController < Api::V2::ApplicationController
  def index
    @attendees = Guest.not_pending(current_user.company_id)
                      .where('"guests"."email" LIKE ?', "%#{params[:email]}%") +
                 Employee.by_company(current_user.company_id)
                         .where('"employees"."email" LIKE ?', "%#{params[:email]}%")
    render
  end
end

