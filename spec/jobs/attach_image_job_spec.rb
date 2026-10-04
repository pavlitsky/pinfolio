require "rails_helper"

RSpec.describe AttachImageJob, type: :job do
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

    it "refreshes pages showing the post (attaching touches the item and post)" do
      item # created before counting
      clear_enqueued_jobs

      described_class.perform_now(item, image_url)

      expect(refresh_broadcasts_for(item.post)).to be >= 1
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
