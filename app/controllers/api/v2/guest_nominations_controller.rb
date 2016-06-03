class Api::V2::GuestNominationsController < Api::V2::ApplicationController

  def index

    return head :bad_method unless params[:inventory_release_id]

    @guest_nominations = RequestAttendance.accessible_by(current_ability).joins(:inventory_release).where(
        attendee_type: 'Guest',
        requester_id: current_user.id,
        inventory_release_id: params[:inventory_release_id],
        inventory_releases: {inventory_release_type: 'guest_nomination'}
    )
  end

  def update_list

    nomination_list = guest_nomination_list_params['guest_nominations']

    nominations_to_delete = []
    nomination_list = nomination_list.map do |nomination|
      attendance = RequestAttendance.find_or_initialize_by(id: nomination[:id])
      # handle delete stuff here

      if attendance.id
        attendance.assign_attributes(
            nomination_preference: nomination[:nomination_preference],
            nomination_notes: nomination[:nomination_notes]
        )
      else
        attendance.assign_attributes(
            attendee_id: nomination[:guest_id],
            attendee_type: 'Guest',
            requester_id: current_user.id,
            inventory_release_id: nomination[:inventory_release_id],
            nomination_preference: nomination[:nomination_preference],
            nomination_notes: nomination[:nomination_notes],
            approval_status: 'pending'
        )
      end


      attendance
    end


    ActiveRecord::Base.transaction do
      nomination_list.each(&:save!)
    end

    @guest_nominations = nomination_list
    render 'index'
    # head :accepted

    # nominations_to_create =



  end

  # def create
  #   nominations_to_create
  # end

  def destroy

  end

  private
  # This is for the array format, which is all we accept at the moment
  def guest_nomination_list_params
    params.permit(guest_nominations: [:id, :guest_id, :nomination_preference, :inventory_release_id, :nomination_notes])
  end

end