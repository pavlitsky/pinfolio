require "rails_helper"

RSpec.describe AttachImageJob, type: :job do
  include Turbo::Broadcastable::TestHelper

  let(:item) { create(:item) }
  let(:image_url) { "https://i.pinimg.com/originals/ab/cd/photo.jpg" }

  context "when the image downloads successfully" do
    before do
      stub_request(:get, image_url).to_return(status: 200, body: file_fixture("image.jpg").read, headers: { "Content-Type" => "image/jpeg" })
    end

    it "attaches the image to the item" do
      described_class.perform_now(item, image_url)

      expect(item.reload.image).to be_attached
      expect(item.image.filename.to_s).to eq("photo.jpg")
      expect(item.image.content_type).to eq("image/jpeg")
    end

    it "broadcasts the refreshed post with the new image" do
      streams = capture_turbo_stream_broadcasts(item.post) { described_class.perform_now(item, image_url) }

      expect(streams.size).to eq(1)
      expect(streams.first["action"]).to eq("replace")
      expect(streams.first["target"]).to eq(ActionView::RecordIdentifier.dom_id(item.post))
      expect(streams.first.at_css("a[href='#{item.url}'] img")).to be_present
    end

    it "uses a host-relative image url in the broadcast, since it is rendered outside a request" do
      streams = capture_turbo_stream_broadcasts(item.post) { described_class.perform_now(item, image_url) }

      expect(streams.first.at_css("a[href='#{item.url}'] img")["src"]).to start_with("/rails/active_storage/")
    end
  end

  context "when the download fails" do
    before { stub_request(:get, image_url).to_return(status: 404) }

    it "leaves the item without an image" do
      described_class.perform_now(item, image_url)

      expect(item.reload.image).not_to be_attached
    end
  end

  context "when the url does not point to an image" do
    before { stub_request(:get, image_url).to_return(status: 200, body: "<html></html>", headers: { "Content-Type" => "text/html" }) }

    it "leaves the item without an image" do
      described_class.perform_now(item, image_url)

      expect(item.reload.image).not_to be_attached
    end
  end
end
