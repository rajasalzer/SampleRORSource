class AlertsController < SiteController
  before_action :authenticate_user!
  before_action :find_source_follower, :only => [:update, :destroy, :on_off_status]
  after_action :alert_constrains, :only => [:index]

  def index
    @followers = current_user.source_followers.where(type: "SourceFollowers::Alerter").order(:id)
  end

  def create
    source = create_domain_source(source_params)
    # Now create the follower
    follower_attributes = create_source_follower(current_user, source, source_params)
    source_follower = ::SourceFollowers::Alerter.new(follower_attributes)
    if source_follower.save
      flash[:success] = "New alert was successfully created."
    else
      flash[:error] = 'Error. Alert follower creation failed.'
      render action: :index
    end
  end

  def update
    if @source_follower.update_attributes(source_follower_params)
      flash[:success] = "Successfully updated."
    else
      flash[:error] = 'Error. Alert source updating failed.'
    end
  end

  def destroy
    if @source_follower.destroy
      redirect_to root_path, :flash => { :success => "Successfully deleted." }
    else
      redirect_to root_path, :flash => { :error => "Error. Alert deletion failed." }
    end
  end

  def on_off_status
    if @source_follower.update_attributes(source_params)
      flash[:success] = "Alert follower was successfully changed."
    else
      flash[:error] = 'Error. Alert follower updating failed.'
    end
  end

  private

  def alert_constrains
    @sources = @followers.collect { |follower| follower.source }
    types = @sources.map(&:type)
    session["domain"]   = types.count("Sources::Domain")
    session["profile"]  = types.count("Sources::Profile")
    session["board"]    = types.count("Sources::Board")
    session["interest"] = types.count("Sources::Interest")
  end

  def create_domain_source(source_params)
    # Check whether pin url is already present else initialize a new object
    domain = ::Sources::Domain.where(pin_url: "/source/#{ source_params[:domain] }/").first_or_initialize
    domain.save

    #Return the domain source
    domain
  end

  def create_source_follower(user, source, source_params)
    # Create source follower if not present already.
    unless user.get_source_followers(source.id)
      record_attributes = {
          user_id: user.id,
          source_id: source.id,
          alert_frequency: follower_frequency(source_params),
          keywords: source_params[:source_follower][:keywords]
      }
      ::SourceFollowers::Alerter.create!(record_attributes)
    end
  end

  def follower_frequency(source_params)
    case source_params[:source_follower][:alert_frequency]
      when '2'
      then :weekly
      when '1'
      then :daily
      when '0'
      then :immediately
      else
        :immediately
    end
  end

  def source_follower_params
    params.require(:source_follower).permit(:alert_frequency, {:keywords => []}, :status)
  end

  def source_params
    params.require(:source_follower).permit(:status)
  end

  def find_source_follower
    @source_follower = current_user.source_followers.find(params[:id])
  end

end
