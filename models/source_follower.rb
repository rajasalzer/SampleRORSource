class SourceFollower < ActiveRecord::Base

  enum status: [:active, :paused, :deleted]

  delegate :subject, :to => :source

  belongs_to :user
  belongs_to :source

  validates :source, :user, :type, :presence => true
  #validates :type, :uniqueness => {scope: [:source_id, :user_id]}
  validates :type, :uniqueness => { :scope => [:user, :source], :message => 'already exists' }

  validates_with ::PlanEnforcer, on: :create

  after_commit :activate_or_deactivate_source

  def kind
    self.class.name.split('::')[1]
  end

  def alert_frequency
    'NA'
  end

  def is_alerter?
    kind == 'Alerter'
  end

  def is_broadcaster?
    kind == 'Broadcaster'
  end

  private

  def activate_or_deactivate_source
    return if source.error?
    if paused?
      followers = source.source_followers.where("status <> ?", SourceFollower.statuses[:paused])
      source.inactive! if followers.count == 0 && source.active?
    else
      source.active! unless source.active? || source.error?
    end
  end

end