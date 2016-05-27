require 'spec_helper'

describe ::Scraping::Downloader do
  let(:page_url) { "http://www.pinterest.com/source/test.com" }
  let(:error) { double('error').as_null_object }
  let(:response_read_error) { Mechanize::ResponseReadError.new(error, nil, nil, nil, nil) }
  
  subject(:downloader) { Scraping::Downloader.new }

  describe '#get_page' do
    context 'Mechanize::ResponseReadError exception is raised twice' do
      it 'retries the request once' do
        allow_any_instance_of(Mechanize).to receive(:get).and_raise(response_read_error)
        expect { downloader.get_page(page_url) }.to raise_error(Mechanize::ResponseReadError)
      end
    end
  end

end