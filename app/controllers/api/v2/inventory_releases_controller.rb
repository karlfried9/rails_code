class Api::V2::InventoryReleasesController < Api::V2::ApplicationController
  include ActionController::MimeResponds
  load_and_authorize_resource except: [:place_bid]

  def index
    if params[:start]
      start = params[:start]
    end

    if params[:finish]
      finish = params[:finish]
    end

    if start && finish
      start = finish if start > finish
      finish = start if finish < start

      #TODO make sure hospitality events are released by the venue!
      @inventory_releases = @inventory_releases.merge(Inventory.with_time_range(start, finish))
                                .joins(inventory:[:event_date])
                                .includes(:department, inventory:[:venue, event_date:[:event]])
    end

    @inventory_releases.where!(inventory_id: params[:inventory_id]) if params[:inventory_id]

    if params[:descendants_of_with]
      @inventory_releases = InventoryRelease.find params[:descendants_of_with]
      @inventory_releases = @inventory_releases.self_and_descendants
    end

    @fields = params[:fields].split ',' if params[:fields]

    # Type for guest nomination etc etc
    @inventory_releases.where! inventory_release_type: params[:inventory_release_type].split(',') if params[:inventory_release_type]

    if params[:with_unapproved_requests] and params[:with_unapproved_requests] == 'true'
      @inventory_releases = @inventory_releases
          .joins(:request_attendances)
          .where(request_attendances:{approval_status: 'pending'}).uniq(:id)
    end

    @inventory_releases = @inventory_releases.total_requested_count_greater_than params[:total_requested_count_greater_than] if params[:total_requested_count_greater_than]
    @inventory_releases = @inventory_releases.total_approved_count_greater_than params[:total_approved_count_greater_than] if params[:total_approved_count_greater_than]

  end

  def download_events
    @inventory_releases = @inventory_releases.find(params[:ids])

    respond_to do |format|
      format.json { render json: {result: @inventory_releases}}
      format.xlsx
    end
  end

  def show

  end

  def update
    respond_to_update @inventory_release, inventory_release_params
  end

  def create
    if respond_to_create @inventory_release
      @inventory_release.send_tickets_allocated_confirmation(request.base_url)
    end
  end


  # Not part of the bidding process. here we approve and allocate the tickets directly to employees
  def allocate_to_employee
    @inventory_release = InventoryRelease.find params[:id]
    authorize! :update, @inventory_release


    if @inventory_release.allocate_to_employee(params[:employee_id], params[:count])
      head :no_content
    else
      head :unprocessable_entity
    end

    # head :no_content # everything went well!
  end

  # Ticket Bidding
  def place_bid
    @inventory_release = InventoryRelease.find params[:id]
    authorize! :update, @inventory_release
    #
    result = @inventory_release.create_request_attendances(params[:quantity], {
                                                                       :special_requests => params[:special],
                                                                       :strategic_reason => params[:strategic_reason],
                                                                       :comments         => params[:comments],
                                                                       :requester_id     => current_user.id,
                                                                       :approval_status  => 'pending'
                                                                   })
    # @inventory_release.create_ticket_bid params[:data]

    if result
      head :created
    else
      head :unprocessable_entity
    end

  end

  # ticket
  def update_bid
    number_of_tickets = params[:quantity]
    requester_id = params[:requester_id]
    perform_action  = params[:perform_action]
    attendances_to_approve = @inventory_release.request_attendances.where(requester_id: requester_id, approval_status: 'pending').take(number_of_tickets)

    status = 'approved' if perform_action == 'approve'
    status = 'rejected' if perform_action == 'reject'

    ActiveRecord::Base.transaction do
      attendances_to_approve.each {|a| a.update_attributes! approval_status: status}
    end
  end

  def split_inventory_release
    # @inventory_release = InventoryRelease.find params[:id]
    # authorize! :show, @inventory_release
    # params type will be guest nominations, direct allocation, etc etc
    # this will call the logic of the split (in the model ofc) so we have one central spot for how to split

    if @inventory_release.perform_split(params[:quantity], params[:split_type], params[:approval_path_id])
      head :no_content
    else
      head :unprocessable_entity
    end
  end

  def revoke
    quantity = params[:quantity].to_i

    if quantity > 0
      if @inventory_release.revoke(quantity)
        head :no_content
      else
        render json: {__errors: @inventory_release.errors}, status: :unprocessable_entity
      end
    else
      head :unprocessable_entity
    end
  end


  private
  def inventory_release_params
    params.require(:inventory_release).permit(
        :inventory_id, :total_released_count, :department_id, :parent_id, :approval_path_id
    )
  end
end

