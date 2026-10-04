require "rails_helper"

RSpec.describe PinterestSearch do
  let(:endpoint) { %r{\Ahttps://www\.pinterest\.com/resource/BaseSearchResource/get/} }
  let(:body) { file_fixture("pinterest_search.json").read }

  before { stub_request(:get, endpoint).to_return(status: 200, body:, headers: { "Content-Type" => "application/json" }) }

  def requested_options
    options = nil
    expect(WebMock).to have_requested(:get, endpoint).with { |request| options = JSON.parse(request.uri.query_values["data"])["options"] }
    options
  end

  describe ".call" do
    it "sends the query to Pinterest" do
      described_class.call("cozy cabin")

      expect(requested_options["query"]).to eq("cozy cabin")
    end

    context "without a bookmark" do
      it "requests the first page" do
        described_class.call("cozy cabin")

        expect(requested_options["bookmarks"]).to eq([])
      end
    end

    context "with a bookmark" do
      it "requests the page after it" do
        described_class.call("cozy cabin", bookmark: "abc")

        expect(requested_options["bookmarks"]).to eq([ "abc" ])
      end
    end

    it "returns the bookmark for the next page" do
      expect(described_class.call("cozy cabin").bookmark).to eq("next-page-bookmark")
    end

    it "returns pin links with their largest available image" do
      expect(described_class.call("cozy cabin").results).to eq([
        described_class::Result.new(url: "https://www.pinterest.com/pin/1001/", image_url: "https://i.pinimg.com/originals/1.jpg"),
        described_class::Result.new(url: "https://www.pinterest.com/pin/1003/", image_url: "https://i.pinimg.com/736x/3.jpg"),
        described_class::Result.new(url: "https://www.pinterest.com/pin/1005/", image_url: "https://i.pinimg.com/originals/5.jpg")
      ])
    end

    it "skips promoted pins, non-pin results and pins without images" do
      urls = described_class.call("cozy cabin").results.map(&:url)

      expect(urls).not_to include("https://www.pinterest.com/pin/1002/", "https://www.pinterest.com/pin/9999/", "https://www.pinterest.com/pin/1004/")
    end

    context "when Pinterest returns no results" do
      let(:body) { { resource_response: { data: { results: [] }, bookmark: "-end-" } }.to_json }

      it "returns an empty page with the end bookmark" do
        expect(described_class.call("cozy cabin")).to eq(described_class::Page.new(results: [], bookmark: described_class::END_BOOKMARK))
      end
    end

    context "when Pinterest responds with an error status" do
      before { stub_request(:get, endpoint).to_return(status: 403) }

      it "raises an error" do
        expect { described_class.call("cozy cabin") }.to raise_error(described_class::Error, /HTTP 403/)
      end
    end

    context "when Pinterest responds with invalid JSON" do
      let(:body) { "<html>blocked</html>" }

      it "raises an error" do
        expect { described_class.call("cozy cabin") }.to raise_error(described_class::Error)
      end
    end

    context "when the request times out" do
      before { stub_request(:get, endpoint).to_timeout }

      it "raises an error" do
        expect { described_class.call("cozy cabin") }.to raise_error(described_class::Error)
      end
    end
  end
end
