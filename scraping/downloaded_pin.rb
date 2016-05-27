module PinScraping
  class DownloadedPin
    
    def initialize(pin_data, source_id, job_guid, batch_guid)
      @data = pin_data
      @source_id = source_id
      @job_guid = job_guid
      @batch_guid = batch_guid
    end

    def attributes
      core = {
        # Pinner Attributes
        :pinner_full_name => pinner_full_name,
        :pinner_id => pinner_id,
        :pinner_image_small_url => pinner_image_small_url,
        :pinner_username => pinner_username,        

        # Pin Attributes
        :pin_id => pin_id,
        :pin_created_at => pin_created_at,
        :comment_count => comment_count,
        :description => description,
        :description_html => description_html,
        :image_236x_url => image_236x_url,
        :image_736x_url => image_736x_url,
        :is_repin => is_repin,
        :is_uploaded => is_uploaded,
        :is_video => is_video,
        :like_count => like_count,
        :link => link,
        :pin_method => pin_method,
        :repin_count => repin_count,
        
        # Misc Attributes
        :source_id => @source_id,
        :job_guid => @job_guid,
        :batch_guid => @batch_guid
      }
            
      if @data['board']
        core.merge!({
          # Board Attributes
          :board_name => board_name,
          :board_id => board_id,
          :board_image_thumbnail_url => board_image_thumbnail_url,
          :board_owner_id => board_owner_id,
          :board_url => board_url,
        })
      end

      core
    end

    def attributes_for_analytics
      analytics_attributes = attributes.dup   
      analytics_attributes[:pin_created_at] = DateTime.parse(analytics_attributes[:pin_created_at])
      analytics_attributes[:is_repin] = analytics_attributes[:is_repin].to_bool
      analytics_attributes[:is_uploaded] = analytics_attributes[:is_uploaded].to_bool
      analytics_attributes[:is_video] = analytics_attributes[:is_video].to_bool
      analytics_attributes
    end

    def pin_id
      Integer(@data['id'])
    end
  
  private

    def board_name
      @data['board']['name']
    end

    def board_id
      Integer(@data['board']['id'])
    end

    def board_image_thumbnail_url
      @data['board']['image_thumbnail_url']
    end

    def board_owner_id
      Integer(@data['board']['owner']['id'])
    end

    def board_url
      @data['board']['url']
    end

    def comment_count
      Integer(@data['comment_count'])
    end

    def pin_created_at
      @data['created_at']
    end

    def description
      return nil unless @data['description'].present?
      @data['description'][0..10000] # Keen (long term storage) has a 10000 character limit per property
    end

    def description_html
      return nil unless @data['description_html'].present?
      @data['description_html'][0..10000] # Keen (long term storage) has a 10000 character limit per property
    end

    def image_236x_url
      @data['images']['236x']['url']
    end

    def image_736x_url
      @data['images']['736x']['url']
    end
    
    def is_repin
      @data['is_repin'].to_bool
    end

    def is_uploaded
      @data['is_uploaded'].to_bool
    end

    def is_video
      @data['is_video'].to_bool
    end

    def like_count
      Integer(@data['like_count'])
    end

    def link
      @data['link']
    end

    def pin_method
      @data['method']
    end

    def pinner_full_name
      @data['pinner']['full_name']
    end

    def pinner_id
      Integer(@data['pinner']['id'])
    end

    def pinner_image_small_url
      @data['pinner']['image_small_url']
    end

    def pinner_username
      @data['pinner']['username']
    end

    def repin_count
      Integer(@data['repin_count'])
    end
  end
end