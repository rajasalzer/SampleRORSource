class Source < ActiveRecord::Base

  enum status: [:active, :inactive, :error]

  has_many :source_followers, :dependent => :destroy
  has_many :pins, :dependent => :destroy

  after_validation :report_validation_errors_to_rollbar
  validates :type, :presence => true
  validates :pin_url, :presence => true, :uniqueness => { :scope => :type, :message => 'already exists.' }

  scope :fuzzy_search, lambda { |term| where("sources.pin_url LIKE '*?*'", term)}

  def kind
    self.class.name.split('::')[1]
  end

  def pin_url=(new_pin_url)
    return if new_pin_url.blank?
    bits = new_pin_url.strip.downcase.split('/').reject(&:empty?)
    self[:pin_url] = "/#{ bits.first }/#{ bits.last }/"
  end

  def subject
    pin_url
  end

end
