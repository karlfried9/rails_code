class Api::V2::MailTemplatesController < Api::V2::ApplicationController
  load_and_authorize_resource except: [:prepare_send]

  def index
    @mail_templates = @mail_templates.editable

    @mail_templates = @mail_templates.where("data->>'mail_type' = '#{params[:mail_type]}'") if params[:mail_type]

    render
  end

  def new
    render :show
  end

  def show
    render
  end

  def destroy
    if @mail_template.destroy
      head :no_content
    else
      head :unprocessable_entity
    end
  end

  def update
    if @mail_template.update_attributes mail_template_params
      render :show
    else
      render json: @mail_template.errors, status: :unprocessable_entity
    end
  end

  def create
    if @mail_template.save
      render :show, status: :created
    else
      render json: @mail_template.errors, status: :unprocessable_entity
    end
  end

  # GET /:id/send
  # Loads the template along with the available choices for the required models
  # Client should then choose what he wants and POST it to /notifications
  def prepare_send
    @mail_template = MailTemplate.find(params[:id])
    # authorize! :show, @mail_template
    # if @mail_template.requires['event']
    @events = Event.includes(:dates).not_closed.accessible_by(current_ability, :index)
    # end

    # TODO fix this slow shiz
    # if @mail_template.requires['company']
    @companies = current_user.company.clients.includes(facility_leases:[:facility])

    # end

    render
  end


  private
  def mail_template_params
    params.require(:mail_template).permit(:id, :subject, :body, :name, :bcc, :reply_to, :mail_type)
  end
end