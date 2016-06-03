class Api::V2::GuestsController < Api::V2::ApplicationController
  load_and_authorize_resource

  include ActionController::MimeResponds

  def index
    @guests.includes!(:tags)

    @guests = @guests.where("data->>'rep_email' = '#{current_user.email}'") if current_user.is_standard_user?

    if params[:tag_names]
      tag_names = params[:tag_names].split ',' if params[:tag_names]
      @guests = @guests.tagged_with(tag_names, any: true)
    end

    @guests = @guests.search_by_name(params[:search]) if params[:search]

    @guests = @guests.limit(params[:limit]) if params[:limit]

  end

  # this datatable stuff is pretty shitty.
  def datatable
    @guests = @guests.where("data->>'rep_email' = '#{current_user.email}'") if current_user.is_standard_user?

    @result = @guests


    params[:filter]. each do |k, v|
      unless v.blank?
        @result = @result.send("search_by_#{k}", v)
      end
    end
    @result = @result.includes(:request_attendances)
    @guests = @result.limit(params[:count]).offset((params[:page].to_i - 1) * params[:count].to_i)
    @guests = @guests.order(params[:sorting].map { |k, v| Guest.stored_attributes[:data].include?(k.to_sym) ? "(guests.data ->> '#{k}') #{v}" : "#{k} #{v}" }.join(', '))
    @total = @result.count
    respond_to do |format|
      format.json { render }
      format.xlsx {
        headers['Content-Transfer-Encoding'] = 'binary'
        headers['Content-Type'] = 'arraybuffer'
        render
      }
      format.pdf {
        headers['Content-Transfer-Encoding'] = 'binary'
        headers['Content-Type'] = 'arraybuffer'
        render
      }
    end
  end

  def show
  end

  def create
    respond_to_create @guest
  end

  def update
    if guest_params[:tag_names]
      guest_params[:tag_names].each do |tag_name|
        @guest.tags.delete_all
        @guest.tag_list.add(tag_name)
      end
    end

    respond_to_update @guest, guest_params
  end

  def destroy
    @guest.destroy
    head :no_content
  end

  def manual_create
    require 'csv'
    file = params[:file]
    filename = file.original_filename

    result_file = "result-"+filename.gsub('.', "-#{Date.today.to_s}.")
    write_mode = 'w'

    FileUtils.mkpath "#{Rails.public_path}/csv"
    FileUtils.move file.tempfile.path, "#{Rails.public_path}/csv/#{filename}"
    File.delete("#{Rails.public_path}/csv/#{result_file}") if File.exist?("#{Rails.public_path}/csv/#{result_file}")
    current_row = 1
    created_count = 0
    updated_count = 0

    CSV.foreach("#{Rails.public_path}/csv/#{filename}", :headers => true, :encoding => 'ISO-8859-1') do |row|
        data = row.to_hash
        new_data = Hash.new

        new_data[:email] = data.delete("Email_Address")

        unless new_data[:email].nil?
          new_data[:email] = new_data[:email].downcase
          new_data[:execdir_name] = data.delete("ED_Name")
          new_data[:salesdir_name] = data.delete("SD_Name")
          new_data[:gm_name] = data.delete("GMS_Name")
          new_data[:rep_name] = data.delete("Rep_Name")
          new_data[:rep_email] = data.delete("Rep_Email")
          new_data[:company] = data.delete("Customer_Name")
          new_data[:crm_1] = data.delete("CIDN")
          new_data[:crm_2] = data.delete("Contact_ID")
          new_data[:courtesy_title] = data.delete("Contact_Title")
          new_data[:last_name] = data.delete("Last_Name")
          new_data[:first_name] = data.delete("First_Name")
          new_data[:job_title] = data.delete("Job_Title")
          new_data[:job_band] = data.delete("Job_Description")
          new_data[:direct_number] = data.delete("Direct")
          new_data[:mobile_number] = data.delete("Mobile")
          new_data[:street_address] = data.delete("Street_Address")
          new_data[:suburb] = data.delete("Suburb")
          new_data[:postcode] = data.delete("Postal_code")
          new_data[:state] = data.delete("State")
          new_data[:crm_communication_status] = data.delete("eOffers")
          if new_data[:crm_communication_status] = 'Opt In'
            new_data[:crm_communication_status] = 'optin'
          elsif new_data[:crm_communication_status] = 'Opt Out'
            new_data[:crm_communication_status] = 'optout'
          elsif new_data[:crm_communication_status] = 'Unknown'
            new_data[:crm_communication_status] = 'unknown'
          end
          desicision_marking_role = data.delete("Decision_Making_Role")
          industry_group_name = data.delete("Sales_Group")
          
          new_data['department_partitioning_id'] = params[:department_id]
          new_data['company_id'] = '4c04a86d-3abe-4690-89e7-46145bf8bd9e'
          guest = Guest.where("company_id='4c04a86d-3abe-4690-89e7-46145bf8bd9e' AND email='#{new_data[:email]}'")
          if guest.blank?
              Guest.create! new_data
              created_count += 1
          else
            guest[0].update_attributes(new_data)
            updated_count += 1
          end

        end
    end

    Guest.rebuild_search_index

    render json: {created_count: created_count, updated_count: updated_count}
  end
  # Split this out into something else one day

  def invited_events
    # @request_attendances = RequestAttendance.where(attendee_type: 'Guest', attendee_id: @guest.id)
    @request_attendances = @guest.request_attendances
  end

  def survey_results

  end

  def event_preferences

  end

  private
  def guest_params
    params.require(:guest).permit(
        :first_name, :last_name, :email, :crm_1, :crm_2,
        :sex, :mobile_number,:direct_number, :position, :company, :revenue, :department_id,
        :job_title, :relevance, :job_band, :execdir_name, :salesdir_name, :rep_name, :rep_email, :local_communication_status, :gm_name,
        :tier, :customer_segment, :street_address, :postcode, :state, :suburb, :title, :postnominal, :personal, :address_with_formal_titles, {tag_names: []}
    )

end

end
