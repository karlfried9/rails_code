class Api::V2::InventoriesController < Api::V2::ApplicationController
  load_and_authorize_resource

  def index

    # @inventories = @inventories.page(params[:page]) if params[:page]

    @inventories = @inventories.includes(:facility, :venue, :event, event_date:[:event], inventory_releases: [:department]).references(:event_date)

    # params end + start are unix timestamps used for date ranging
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
      @inventories = @inventories.merge(Inventory.with_time_range(start, finish))
    end






    case params[:status]
      when 'current' then @inventories = @inventories.merge(Inventory.current)
      when 'upcoming' then @inventories = @inventories.merge(Inventory.current)
      when 'past' then @inventories = @inventories.merge(EventDate.finished)
    end

    case params[:type]
      when 'sponsorship' then @inventories = @inventories.merge Inventory.sponsorship
      when 'hospitality' then @inventories = @inventories.merge Inventory.hospitality
    end

  end

  def show

  end

  def update
    respond_to_update @inventory, inventory_params
  end

  def create
    respond_to_create @inventory
  end

  private
  def inventory_params
    params.require(:inventory).permit(
        :facility_id, :company_id, :total, :status, :created_by_client, :event_name, :event_date_start, :event_date_finish,
        :valuation_complete, :notional_value, :catering_value, :gift_value, :other_value,
        :inclusions, :has_catering, :ticket_type, :on_hold, :is_reward_and_recognition, :is_child_friendly,
        :allocations_require_approval, :guest_nominations_allowed, :guest_nomination_notes, :bidding_allowed, :direct_allocation_allowed,
        :host_brief, :delete_host_brief, :is_parking_offered, :ask_survey_permission, :confirm_mail_template, ticket_numbers: [],
        inventory_releases_attributes: [
            :id, :department_id, :total_released_count
        ]
    )
  end

end