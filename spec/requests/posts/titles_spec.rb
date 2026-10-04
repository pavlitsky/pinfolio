require "rails_helper"

RSpec.describe "/posts/:post_id/title", type: :request do
  include ActionView::RecordIdentifier

  let!(:post_record) { create(:post, title: "cozy cabin", pinterest_bookmark: "b3") }
  let(:frame_headers) { { "Turbo-Frame" => dom_id(post_record, :title) } }

  def frame = Nokogiri::HTML(response.body).at_css("turbo-frame##{dom_id(post_record, :title)}")

  describe "GET /show" do
    it "renders the title in its frame, linking to the inline editor" do
      get(post_title_url(post_record), headers: frame_headers)

      link = frame.at_css("h2 a")
      expect(link.text.strip).to eq("cozy cabin")
      expect(link["href"]).to eq(edit_post_title_path(post_record))
    end
  end

  describe "GET /edit" do
    it "renders the inline form in the same frame, wired to the inline-edit controller" do
      get(edit_post_title_url(post_record), headers: frame_headers)

      form = frame.at_css("form[action='#{post_title_path(post_record)}']")
      expect(form["data-controller"]).to eq("inline-edit")
      expect(form.at_css("input[name='_method']")["value"]).to eq("patch")

      input = form.at_css("input[name='post[title]']")
      expect(input["value"]).to eq("cozy cabin")
      expect(input["data-inline-edit-target"]).to eq("input")
      expect(form.at_css("a[data-inline-edit-target='cancel']")["href"]).to eq(post_title_path(post_record))
    end
  end

  describe "PATCH /update" do
    context "with a new title" do
      it "renames the post" do
        patch(post_title_url(post_record), params: { post: { title: "snowy cabin" } }, headers: frame_headers)

        expect(post_record.reload.title).to eq("snowy cabin")
      end

      it "restarts the Pinterest search for the new title" do
        patch(post_title_url(post_record), params: { post: { title: "snowy cabin" } }, headers: frame_headers)

        expect(post_record.reload.pinterest_bookmark).to be_nil
      end

      it "keeps the post's items" do
        create(:item, post: post_record)

        expect { patch(post_title_url(post_record), params: { post: { title: "snowy cabin" } }, headers: frame_headers) }
          .not_to change(post_record.items, :count)
      end

      it "redirects back to the title so the frame shows it" do
        patch(post_title_url(post_record), params: { post: { title: "snowy cabin" } }, headers: frame_headers)

        expect(response).to redirect_to(post_title_url(post_record))
        expect(response).to have_http_status(:see_other)
      end
    end

    context "with a blank title" do
      it "keeps the old title and re-renders the form with the error" do
        patch(post_title_url(post_record), params: { post: { title: "" } }, headers: frame_headers)

        expect(response).to have_http_status(:unprocessable_content)
        expect(post_record.reload.title).to eq("cozy cabin")
        expect(frame.at_css("form")).to be_present
        expect(frame.text).to include("Title can't be blank")
      end
    end
  end

  context "when the post does not exist" do
    it "responds with not found" do
      get post_title_url(post_id: 0)
      expect(response).to have_http_status(:not_found)
    end
  end
end
