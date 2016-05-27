require 'spec_helper'

describe ::PinScraping::Scraper do

  describe 'scrape' do
    let(:source) { FactoryGirl.create(:domain, :last_scraped_at => 5.seconds.ago) }
    let(:body) { html_page('domain_page.html') }

    subject(:scraper) { ::PinScraping::Scraper.new(source.id, 'test-batch-guid') }

    before { allow(scraper).to receive(:get_page).and_return(body) }

    context 'there are 25 pins to persist' do
      it 'persists the pins' do
        expect(::Pin.count).to eq 0
        scraper.scrape_pins
        expect(::Pin.count).to eq 25
      end

      it 'reports the correct analytics' do
        expect(::Analytics::Publisher).to receive(:publish) do |collection, data|
          expect(collection).to eq Analytics::Scrape
          expect(data[:event]).to eq 'pin scrape'
          expect(data[:source_id]).to eq source.id
          expect(data[:type]).to eq source.class.name
          expect(data[:job_guid]).to be_present
          expect(data[:batch_guid]).to eq 'test-batch-guid'
          expect(data[:pins_found]).to eq 25
          expect(data[:pins_added]).to eq 25
          expect(data[:status]).to eq 'finished'
        end
        scraper.scrape_pins
      end
    end

    context 'duplicate pins exist' do
      it 'does not insert the duplicates' do
        expect(::Pin.count).to eq 0
        scraper.scrape_pins
        expect(::Pin.count).to eq 25
        scraper.scrape_pins
        expect(::Pin.count).to eq 25
      end
    end

    context 'error is raised' do
      let(:error_message) { 'Something bad happened.' }
      before { allow(scraper).to receive(:get_page).and_raise(RuntimeError, error_message) }

      it 'reports the error' do
        expect(::Core::Errors).to receive(:report) do |e|
          expect(e.message).to eq error_message
        end
        scraper.scrape_pins
      end

      it 'sends an error status in the analytics report' do
        expect(::Analytics::Publisher).to receive(:publish) do |collection, data|
          expect(data[:pins_found]).to eq 0
          expect(data[:pins_added]).to eq 0
          expect(data[:status]).to eq 'error'
          expect(data[:status_message]).to eq error_message
        end
        scraper.scrape_pins
      end
    end

    context 'downloaded page is malformed' do
      let(:body) { 'malformed' }

      it 'silently fails' do
        expect { scraper.scrape_pins }.to_not raise_error
      end

      it 'sends an abort status in the analytics report' do
        expect(::Analytics::Publisher).to receive(:publish) do |collection, data|
          expect(data[:pins_found]).to eq 0
          expect(data[:pins_added]).to eq 0
          expect(data[:status]).to eq 'finished'
        end
        scraper.scrape_pins
      end
    end

    it 'updates the source#last_scraped_at field' do
      previous_scrape_date = source.last_scraped_at
      scraper.scrape_pins
      expect(source.reload.last_scraped_at).to be > previous_scrape_date
    end
  end

end