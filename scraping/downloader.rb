module Scraping
  class Downloader

    RETRY_RESCUE_CLASSES = [Mechanize::ResponseCodeError, Mechanize::ResponseReadError, Timeout::Error]

    def get_page(uri)
      with_retries(:max_tries => 2, :rescue => RETRY_RESCUE_CLASSES) do
        logged_in_agent { |agent| agent.get(uri) }
      end
    end

    private

    def logged_in_agent
      $pinterest_agent_pool.with do |agent|
        yield(agent)
      end
    end

  end
end

