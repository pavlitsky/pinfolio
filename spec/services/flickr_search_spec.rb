require "rails_helper"

RSpec.describe FlickrSearch do
  let(:endpoint) { %r{\Ahttps://api\.flickr\.com/services/rest} }
  let(:search_page) { "https://www.flickr.com/search/" }
  let(:site_key_html) { ->(key) { %(<script>root.YUI_config.flickr.api.site_key = "#{key}";</script>) } }
  let(:body) { file_fixture("flickr_search.json").read }
  let(:cache) { ActiveSupport::Cache::MemoryStore.new }

  before do
    allow(Rails).to receive(:cache).and_return(cache)
    stub_request(:get, search_page).to_return(status: 200, body: site_key_html.("abc123"))
    stub_request(:get, endpoint).to_return(status: 200, body:, headers: { "Content-Type" => "application/json" })
  end

  def requested_params
    params = nil
    expect(WebMock).to have_requested(:get, endpoint).with { |request| params = request.uri.query_values }.at_least_once
    params
  end

  describe ".call" do
    it "searches photos for the query by relevance" do
      described_class.call("уютный домик")

      expect(requested_params).to include("method" => "flickr.photos.search", "text" => "уютный домик", "sort" => "relevance", "media" => "photos")
    end

    it "authenticates with the site key scraped from flickr.com" do
      described_class.call("cozy cabin")

      expect(requested_params["api_key"]).to eq("abc123")
    end

    it "reuses the cached site key" do
      2.times { described_class.call("cozy cabin") }

      expect(WebMock).to have_requested(:get, search_page).once
    end

    context "without a cursor" do
      it "requests the first page" do
        described_class.call("cozy cabin")

        expect(requested_params["page"]).to eq("1")
      end
    end

    context "with a cursor" do
      it "requests that page" do
        described_class.call("cozy cabin", cursor: "3")

        expect(requested_params["page"]).to eq("3")
      end
    end

    it "returns the next page number as the cursor" do
      expect(described_class.call("cozy cabin").cursor).to eq("2")
    end

    it "returns photo page links with their largest available image, skipping photos without one" do
      expect(described_class.call("cozy cabin").results).to eq([
        ImageSearch::Result.new(url: "https://www.flickr.com/photos/11111111@N01/1001/", image_url: "https://live.staticflickr.com/65535/1001_a_k.jpg"),
        ImageSearch::Result.new(url: "https://www.flickr.com/photos/22222222@N02/1002/", image_url: "https://live.staticflickr.com/65535/1002_b_b.jpg")
      ])
    end

    context "on the last page" do
      let(:body) { JSON.parse(file_fixture("flickr_search.json").read).deep_merge("photos" => { "page" => 3 }).to_json }

      it "returns no cursor" do
        expect(described_class.call("cozy cabin", cursor: "3").cursor).to be_nil
      end
    end

    context "when Flickr returns no photos" do
      let(:body) { { photos: { page: 1, pages: 0, photo: [] }, stat: "ok" }.to_json }

      it "returns an empty last page" do
        expect(described_class.call("cozy cabin")).to eq(ImageSearch::Page.new(results: [], cursor: nil))
      end
    end

    context "when the cached site key has expired" do
      let(:invalid_key) { { stat: "fail", code: 100, message: "Invalid API Key (Key has expired)" }.to_json }

      before do
        cache.write(described_class::SITE_KEY_CACHE_KEY, "old")
        stub_request(:get, endpoint).with(query: hash_including("api_key" => "old")).to_return(status: 200, body: invalid_key)
      end

      it "scrapes a new site key and retries" do
        expect(described_class.call("cozy cabin").results.size).to eq(2)

        expect(WebMock).to have_requested(:get, endpoint).with(query: hash_including("api_key" => "abc123"))
        expect(cache.read(described_class::SITE_KEY_CACHE_KEY)).to eq("abc123")
      end

      context "and the new key is rejected too" do
        before { stub_request(:get, endpoint).to_return(status: 200, body: invalid_key) }

        it "raises an error" do
          expect { described_class.call("cozy cabin") }.to raise_error(ImageSearch::Error, /Invalid API Key/)
        end
      end
    end

    context "when the site key can't be found on flickr.com" do
      before { stub_request(:get, search_page).to_return(status: 200, body: "<html></html>") }

      it "raises an error" do
        expect { described_class.call("cozy cabin") }.to raise_error(ImageSearch::Error, /site key not found/)
      end
    end

    context "when Flickr responds with an error status" do
      before { stub_request(:get, endpoint).to_return(status: 503) }

      it "raises an error" do
        expect { described_class.call("cozy cabin") }.to raise_error(ImageSearch::Error, /HTTP 503/)
      end
    end

    context "when the request times out" do
      before { stub_request(:get, endpoint).to_timeout }

      it "raises an error" do
        expect { described_class.call("cozy cabin") }.to raise_error(ImageSearch::Error)
      end
    end
  end
end
