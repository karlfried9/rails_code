# This controller is for the client admin inventory page + client inventory creation, it steps away from conventions because it has to.
# I know it is ugly as hell, and that I am probably going to hell for writing it.


class Api::V2::ClientEventsController < Api::V2::ApplicationController

  def create

    # If the venue is not created, we have to create everything (event, date, facility, lease, inventory etc.)
    # If the venue exists, but the event is not created we have to create the event, the dates
    # CRM Link - Employee ID
    client_company = current_user.company
    event_start = params[:inventory][:event_start].presence || 0
    event_finish = params[:inventory][:event_finish].presence || 0
    event_name = params[:inventory][:event_name].presence


    begin
      ActiveRecord::Base.transaction do #

        venue = params[:inventory][:venue_id] ? Venue.find(params[:inventory][:venue_id]) : create_venue(params[:inventory][:venue_name])
        event = params[:inventory][:event_id] ? Event.find(params[:inventory][:event_id]) : create_event(venue, params[:inventory][:event_name], params[:inventory][:event_type])
        event_date = params[:inventory][:event_date_id] ? EventDate.find(params[:inventory][:event_date_id]) : create_event_date(event, event_start, event_finish)

        facility = create_or_find_facility(venue, client_company, params[:inventory][:asset_type], 9000)
        facility_lease = create_facility_lease(facility, client_company, event_date)
        @inventory = create_inventory(facility, event_date, client_company, params[:inventory])
        return render 'api/v2/inventories/show', status: :created

      end
        # rescue Exception => e
        #   return head status: :unprocessable_entity
        # something went wrong, transaction rolled back
      end

  end

  # Seems kinda stupid, maybe i make a nested resource in venue.
  def events_for_venue
    @events = []

    if params[:venue_id]
      @events = Event.where(venue_id: params[:venue_id]).eager_load(:dates).merge(EventDate.not_finished)
    end

  end



  def nested_departments_index
    @departments = Department.where(parent_id: nil).accessible_by current_ability
  end

  def delete_inventory
    @inventory = Inventory.find params[:id]
    event = @inventory.event
    if @inventory.destroy
      if event.destroy
        head :no_content
      end
    end

  end

  private
  def create_venue(name)
    Venue.create! name: name, created_by_client: true
  end

  def create_event(venue, name, event_type)
    Event.create! venue: venue, name: name, status: 'Open', event_type: event_type
  end

  def create_event_date(event, start, finish)
    EventDate.create! event: event, start: start, finish: finish
  end


  def create_or_find_facility(venue, client, type, count)
    if type == 'sponsorship'
      name = "#{client.name} - Sponsorship"
    else
      name = "#{client.name} - Hospitality"
      type = 'Suite'
    end

    facility = Facility.where(name: name, venue: venue).first

    if facility
      if facility.capacity < count
        facility.update_attribute(:capacity, count)
      end
      facility
    else
      Facility.create!(venue: venue, name: name, facility_type: type, capacity: count)
    end
  end

  def create_facility_lease(facility, client, event_date)
    FacilityLease.create! facility: facility, client: client, start: event_date.start, finish: event_date.finish, is_enabled: true, venue_id: facility.venue_id
  end

  def create_inventory(facility, event_date, client, params)
    Inventory.create! facility: facility, event_date: event_date, venue: facility.venue, client: client, total: params[:count],
                      created_by_client: true, asset_type: params[:asset_type], ticket_type: params[:ticket_type], inclusions: params[:inclusions],
                      is_parking_offered: params[:is_parking_offered], guest_nomination_notes: params[:guest_nomination_notes],
                      host_brief: params[:host_brief], notional_value: params[:notional_value], catering_value: params[:catering_value],
                      gift_value: params[:gift_value], other_value: params[:other_value], direct_allocation_allowed: params[:direct_allocation_control],
                      guest_nominations_allowed: params[:guest_nomination_control], bidding_allowed: params[:bidding_control],
                      ask_survey_permission: params[:ask_survey_permission], confirm_mail_template: params[:confirm_mail_template],
                      on_hold: params[:on_hold], is_reward_and_recognition: params[:is_reward_and_recognition], has_catering: params[:has_catering],
                      is_child_friendly: params[:is_child_friendly]
  end

end