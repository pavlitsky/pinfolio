require "rails_helper"

RSpec.describe "/posts", type: :request do
  let(:valid_attributes) { { title: "My post" } }
  let(:invalid_attributes) { { title: "" } }

  describe "GET /index" do
    it "renders a successful response" do
      create(:post)
      get posts_url
      expect(response).to be_successful
    end
  end

  describe "GET / (root)" do
    let!(:post_record) { create(:post, title: "Holiday photos") }

    def attach_image(item)
      item.image.attach(io: StringIO.new("fake image"), filename: "photo.jpg", content_type: "image/jpeg")
    end

    it "shows the idea input without a label" do
      get root_url

      input = Nokogiri::HTML(response.body).at_css("form#idea_form input[name='post[title]']")
      expect(input["placeholder"]).to eq("Search anything...")
      expect(response.body).not_to include("<label", "New post")
    end

    it "offers a delete (×) button in the post's title row" do
      get root_url

      entry = Nokogiri::HTML(response.body).at_css("##{ActionView::RecordIdentifier.dom_id(post_record, :entry)}")
      expect(entry["data-controller"]).to eq("removal")
      title_row = entry.at_css("h2").parent
      expect(title_row.css("button").map { |button| button.text.strip }).to eq([ "×" ])
      button = title_row.at_css("form[action='#{post_path(post_record)}'] button")
      expect(button["aria-label"]).to eq("Delete post “Holiday photos”")
      expect(entry.at_css(".group\\/post")).to be_present
      expect(button["class"]).to include("opacity-0", "group-hover/post:opacity-100")
      expect(title_row.at_css("form input[name='_method']")["value"]).to eq("delete")
    end

    it "lists posts newest first" do
      newer_post = create(:post, title: "Wedding photos", created_at: 1.minute.from_now)

      get root_url

      expect(response.body.index(newer_post.title)).to be < response.body.index(post_record.title)
    end

    it "lists all posts with their titles" do
      other_post = create(:post, title: "Wedding photos")

      get root_url

      expect(response).to be_successful
      expect(response.body).to include(post_record.title, other_post.title)
    end

    context "when items have images" do
      let!(:item) { create(:item, post: post_record, url: "https://example.com/original.jpg").tap { |i| attach_image(i) } }

      it "renders each image linking to the item url in a new tab" do
        get root_url

        link = Nokogiri::HTML(response.body).at_css("##{ActionView::RecordIdentifier.dom_id(item, :image)}")
        expect(link["href"]).to eq(item.url)
        expect(link["target"]).to eq("_blank")
        expect(link["rel"]).to include("noopener")
        expect(link.at_css("img")).to be_present
      end

      it "renders a hide (×) button in the image tile's top-right corner" do
        get root_url

        tile = Nokogiri::HTML(response.body).at_css("##{ActionView::RecordIdentifier.dom_id(item, :tile)}")
        expect(tile["data-controller"]).to eq("removal")
        expect(tile["data-removal-style-value"]).to eq("shrink")

        form = tile.at_css("form[action='#{hide_item_path(item)}']")
        expect(form["class"]).to include("absolute", "top-0", "right-0")
        expect(form.at_css("input[name='_method']")["value"]).to eq("patch")
        expect(form.at_css("button")["aria-label"]).to eq("Hide image")
        expect(form.at_css("button")["class"]).to include("opacity-0", "group-hover:opacity-100")
      end
    end

    context "when items have no images" do
      let!(:item) { create(:item, post: post_record) }

      it "does not render an image tile for them" do
        get root_url

        expect(response.body).not_to include(ActionView::RecordIdentifier.dom_id(item, :tile))
      end
    end

    context "when an item is hidden" do
      let!(:item) { create(:item, post: post_record, hidden_at: Time.current).tap { |i| attach_image(i) } }

      it "does not render its image" do
        get root_url

        expect(response.body).not_to include(ActionView::RecordIdentifier.dom_id(item, :tile))
      end
    end

    describe "the Add More tile" do
      def add_more_tile
        Nokogiri::HTML(response.body).at_css("##{ActionView::RecordIdentifier.dom_id(post_record, :add_more)}")
      end

      it "is the last tile in the post's grid" do
        create(:item, post: post_record).tap { |i| attach_image(i) }

        get root_url

        expect(add_more_tile.parent.element_children.last["id"]).to eq(add_more_tile["id"])
      end

      it "posts to collect more pins for the post" do
        get root_url

        form = add_more_tile.at_css("form[action='#{post_pins_path(post_record)}']")
        expect(form["method"]).to eq("post")
        expect(form.at_css("button").text.strip).to eq("Add More")
      end

      context "when Pinterest has no more pages" do
        before { post_record.update!(pinterest_bookmark: PinterestSearch::END_BOOKMARK) }

        it "shows No more instead of a button" do
          get root_url

          expect(add_more_tile.at_css("button")).to be_nil
          expect(add_more_tile.text.strip).to eq("No more")
        end
      end
    end
  end

  describe "removed pages" do
    let(:post_record) { create(:post) }

    { "new" => "/posts/new", "show" => "/posts/:id", "edit" => "/posts/:id/edit" }.each do |page, path|
      it "has no #{page} page" do
        get path.sub(":id", post_record.id.to_s)
        expect(response).to have_http_status(:not_found)
      end
    end

    it "has no JSON list" do
      get posts_url(format: :json)
      expect(response).to have_http_status(:not_acceptable)
    end

    it "does not allow updating a post" do
      patch "/posts/#{post_record.id}", params: { post: { title: "Updated title" } }

      expect(response).to have_http_status(:not_found)
      expect(post_record.reload.title).not_to eq("Updated title")
    end
  end

  describe "POST /create" do
    context "with valid parameters" do
      it "creates a new Post" do
        expect { post posts_url, params: { post: valid_attributes } }.to change(Post, :count).by(1)
      end

      it "redirects to the posts list" do
        post posts_url, params: { post: valid_attributes }
        expect(response).to redirect_to(root_url)
      end

      it "starts collecting pins for the post" do
        post posts_url, params: { post: valid_attributes }
        expect(CollectPinsJob).to have_been_enqueued.with(Post.last)
      end
    end

    context "with invalid parameters" do
      it "does not create a new Post" do
        expect { post posts_url, params: { post: invalid_attributes } }.not_to change(Post, :count)
      end

      it "re-renders the posts list with the error" do
        create(:post, title: "Existing post")

        post posts_url, params: { post: invalid_attributes }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("Existing post", "Title can&#39;t be blank")
      end

      it "does not collect pins" do
        post posts_url, params: { post: invalid_attributes }
        expect(CollectPinsJob).not_to have_been_enqueued
      end
    end

    context "as a Turbo Stream (the idea input)" do
      let(:headers) { { "Accept" => "text/vnd.turbo-stream.html, text/html" } }

      context "with a title" do
        it "creates the post and starts collecting pins" do
          expect { post posts_url, params: { post: valid_attributes }, headers: }.to change(Post, :count).by(1)
          expect(CollectPinsJob).to have_been_enqueued.with(Post.last)
        end

        it "prepends the post to the list and resets the input" do
          post(posts_url, params: { post: valid_attributes }, headers:)

          expect(response.media_type).to eq("text/vnd.turbo-stream.html")
          streams = Nokogiri::HTML(response.body).css("turbo-stream")
          expect(streams.map { |stream| [ stream["action"], stream["target"] ] }).to eq([ %w[replace idea_form], %w[prepend posts] ])
          expect(streams.first.at_css("template input[name='post[title]']")["value"]).to be_nil
          expect(streams.last.inner_html).to include("My post")
        end
      end

      context "with a blank title" do
        it "does not create a post" do
          expect { post posts_url, params: { post: invalid_attributes }, headers: }.not_to change(Post, :count)
        end

        it "re-renders the input with the error" do
          post(posts_url, params: { post: invalid_attributes }, headers:)

          expect(response).to have_http_status(:unprocessable_content)
          expect(response.body).to include('action="replace" target="idea_form"', "Title can&#39;t be blank")
        end
      end
    end
  end

  describe "DELETE /destroy" do
    let!(:post_record) { create(:post) }

    it "destroys the requested post and its items" do
      create(:item, post: post_record)

      expect { delete post_url(post_record) }
        .to change(Post, :count).by(-1)
        .and change(Item, :count).by(-1)
    end

    it "redirects to the posts list" do
      delete post_url(post_record)
      expect(response).to redirect_to(root_url)
    end

    context "as a Turbo Stream (the × button)" do
      let(:headers) { { "Accept" => "text/vnd.turbo-stream.html, text/html" } }

      it "destroys the post" do
        expect { delete(post_url(post_record), headers:) }.to change(Post, :count).by(-1)
      end

      it "removes only the post's entry from the page" do
        delete(post_url(post_record), headers:)

        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
        streams = Nokogiri::HTML(response.body).css("turbo-stream")
        expect(streams.map { |stream| [ stream["action"], stream["target"] ] })
          .to eq([ [ "remove", ActionView::RecordIdentifier.dom_id(post_record, :entry) ] ])
      end
    end
  end
end
