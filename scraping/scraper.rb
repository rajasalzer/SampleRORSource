module PinScraping
  class Scraper
    include Sidekiq::Worker
    include ::PinScraping::Jobber

    sidekiq_options :queue => :scraping, :retry => 1

    def initialize(source_id, batch_guid)
      @source_id = source_id
      @batch_guid = batch_guid
      @job_events = [] # Used by ::PinScraping::Jobber
      @pins_found = 0
    end

    def self.scrape(source_id, batch_guid)
      new(source_id, batch_guid).scrape_pins
    end

    def self.scrape_async(source_id, batch_guid)
      delay(sidekiq_options_hash).scrape(source_id, batch_guid)
    end

    def scrape_pins
      analytics[:start_time] = Time.now
      @pins_added = nil

      if downloaded_pins.present?
        dedupe_downloaded_pins
        @pins_added = save_downloaded_pins        
      else
        analytics[:status_message] = 'No pins found in downloaded page.'
      end

      analytics[:status] = 'finished'
      update_source
      update_jobs(@pins_added) unless @pins_added.blank?

      return @pins_added ? @pins_added.size : 0
    rescue Mechanize::ResponseCodeError => e
      if e.message =~ /404/
        analytics[:status] = 'finished'
        analytics[:status_message] = e.message
      else
        analytics[:status] = 'error'
        analytics[:status_message] = e.message
        ::Core::Errors.report(e)
      end
    rescue => e
      analytics[:status] = 'error'
      analytics[:status_message] = e.message
      ::Core::Errors.report(e)
    ensure
      analytics[:end_time] = Time.now
      analytics[:pins_found] = @pins_found
      analytics[:total_time] = analytics[:end_time] - analytics[:start_time]
      ::Analytics::Publisher.publish(::Analytics::Scrape, analytics)
      ::Analytics::Publisher.publish_batch(::Analytics::Job, @job_events)
    end

    def source
      @source ||= Source.find(@source_id)
    end

    private

    def analytics
      @analytics ||= {
        :event => 'pin scrape',
        :source_id => @source_id,
        :type => source.type,
        :job_guid => job_guid,
        :batch_guid => @batch_guid,
        :status => 'started',
        :pins_found => 0,
        :pins_added => 0
      }
    end

    def build_activerecord_pins(downloaded_pins)
      downloaded_pins.map { |p| ::Pin.new(p.attributes) }
    end

    def data_hash
      JSON.parse(json_data) if json_data
    end

    def dedupe_downloaded_pins
      return unless downloaded_pins.present?

      # Remove duplicates in the downloaded batch
      downloaded_pins.uniq! { |p| p.pin_id }

      # Remove pins that are already in the database
      existing_pins(downloaded_pins).each do |pin|
        downloaded_pins.delete_if { |p| p.pin_id == pin.pin_id }
      end
    end

    def downloader
      @downloader ||= ::Scraping::Downloader.new
    end

    def downloaded_pins
      @downloaded_pins ||= begin
        if raw_pins.blank?
          []
        else
          @pins_found += raw_pins.size
          raw_pins.collect { |raw_pin| ::PinScraping::DownloadedPin.new(raw_pin, @source_id, job_guid, @batch_guid) }
        end
      end
    end

    def existing_pins(downloaded_pins)
      ::Pin.select(:pin_id).where(:pin_id => downloaded_pins.map(&:pin_id))
    end

    def job_guid
      @job_guid ||= ::Core::Guid.generate(:job)
    end

    def json_data
      return if source_page.blank?

      @json_data ||= begin
        json_data = source_page.match(/({"gaAccountNumbers".*"canDebug": false})/)
        json_data[0] if json_data
      end
    end

    def get_page(url)
      downloaded_started = Time.now
      page = downloader.get_page(url)
      analytics[:download_time] = Time.now - downloaded_started
      
      page.try(:body)
    end

    def persist_for_analytics
      return if @pins_added.empty?

      analytics_pins = @pins_added.inject([]) do |bucket, pin|
        pin_attributes = pin.attributes
        pin_attributes[:active_record_id] = pin_attributes.delete('id')
        bucket << pin_attributes
      end
      ::Analytics::Pin.collection.insert(analytics_pins)
    end

    def raw_pins
      @raw_pins ||= source.pin_extractor(data_hash)
    end

    def save_downloaded_pins
      return if downloaded_pins.blank?

      ar_pins = build_activerecord_pins(downloaded_pins)

      # Save to Database
      results = ::Pin.import(ar_pins)
      @pins_added = Pin.where(:job_guid => job_guid)

      # Save to Analytics Datastore
      persist_for_analytics

      # Report validation errors
      if results.failed_instances.present?
        results.failed_instances.each do |failed_pin|
          ::Core::Errors.message(failed_pin.errors.full_messages.to_sentence, {}, 'error')
        end
      end

      # Report on added pins
      results.failed_instances.each do |pin|
        ar_pins.delete_if { |p| p.pin_id == pin.pin_id }
      end
      analytics[:pins_added] += ar_pins.size

      @pins_added
    end

    def source_page
      @source_page ||= get_page("http://www.pinterest.com#{ source.pin_url }")
    end

    def update_source
      source.update_attribute(:last_scraped_at, Time.now)
    end

  end
end