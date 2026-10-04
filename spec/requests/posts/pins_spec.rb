require "rails_helper"

RSpec.describe "/posts/:post_id/pins", type: :request do
  let!(:post_record) { create(:post) }

  describe "POST /create" do
    it "starts collecting more pins for the post" do
      post post_pins_url(post_record)
      expect(CollectPinsJob).to have_been_enqueued.with(post_record)
    end

    it "redirects to the posts list" do
      post post_pins_url(post_record)
      expect(response).to redirect_to(root_url)
    end

    context "as a Turbo Stream (the Add More tile)" do
      let(:headers) { { "Accept" => "text/vnd.turbo-stream.html, text/html" } }

      it "switches the Add More tile to its loading state" do
        post(post_pins_url(post_record), headers:)

        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
        stream = Nokogiri::HTML(response.body).at_css("turbo-stream")
        expect([ stream["action"], stream["target"] ]).to eq([ "replace", ActionView::RecordIdentifier.dom_id(post_record, :add_more) ])
        expect(stream.at_css("template").inner_html).to include("Loading…")
        expect(stream.at_css("template button")).to be_nil
      end
    end

    context "when the post does not exist" do
      it "responds with not found" do
        post post_pins_url(post_id: 0)
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
