require "rails_helper"

RSpec.describe CollectPinsJob, type: :job do
  let(:post) { create(:post, title: "cozy cabin") }

  def result(id) = ImageSearch::Result.new(url: "https://www.pinterest.com/pin/#{id}/", image_url: "https://i.pinimg.com/originals/#{id}.jpg")

  def page(ids, cursor:) = ImageSearch::Page.new(results: ids.map { |id| result(id) }, cursor:)

  def stub_pages(pages)
    allow(PinterestSearch).to receive(:call) { |_query, cursor:| pages.fetch(cursor) }
  end

  describe "first collection" do
    before { stub_pages(nil => page(1..12, cursor: "b1")) }

    it "searches Pinterest using the post title from the first page" do
      described_class.perform_now(post)

      expect(PinterestSearch).to have_received(:call).with("cozy cabin", cursor: nil)
    end

    it "creates up to 10 items linking to the pins, in result order" do
      described_class.perform_now(post)

      expect(post.items.pluck(:url)).to eq((1..10).map { |id| result(id).url })
    end

    it "enqueues an image download per item" do
      described_class.perform_now(post)

      post.items.each_with_index do |item, index|
        expect(AttachImageJob).to have_been_enqueued.with(item, result(index + 1).image_url)
      end
    end

    it "saves the cursor for the next collection" do
      described_class.perform_now(post)

      expect(post.reload.search_cursor).to eq("b1")
    end
  end

  context "when the post's source is Flickr" do
    let(:post) { create(:post, title: "cozy cabin", source: :flickr) }

    before { allow(FlickrSearch).to receive(:call).and_return(page(1..3, cursor: "2")) }

    it "searches Flickr instead of Pinterest" do
      allow(PinterestSearch).to receive(:call)

      described_class.perform_now(post)

      expect(FlickrSearch).to have_received(:call).with("cozy cabin", cursor: nil)
      expect(PinterestSearch).not_to have_received(:call)
      expect(post.items.pluck(:url)).to eq((1..3).map { |id| result(id).url })
      expect(post.reload.search_cursor).to eq("2")
    end
  end

  describe "collecting more" do
    let(:post) { create(:post, title: "cozy cabin", search_cursor: "b1") }

    before { stub_pages("b1" => page(11..20, cursor: "b2"), "b2" => page(21..30, cursor: "b3")) }

    it "continues from the saved cursor" do
      described_class.perform_now(post)

      expect(PinterestSearch).to have_received(:call).with("cozy cabin", cursor: "b1")
      expect(post.items.pluck(:url)).to eq((11..20).map { |id| result(id).url })
      expect(post.reload.search_cursor).to eq("b2")
    end

    context "when results duplicate existing items, including hidden ones" do
      before do
        create(:item, post:, url: result(11).url)
        create(:item, post:, url: result(12).url, hidden_at: Time.current)
      end

      it "skips them and keeps paging until 10 new items are collected" do
        expect { described_class.perform_now(post) }.to change(post.items, :count).by(10)

        expect(post.items.pluck(:url)).to eq(([ 11, 12 ] + (13..22).to_a).map { |id| result(id).url })
        expect(post.reload.search_cursor).to eq("b3")
      end

      it "does not download images for the duplicates" do
        described_class.perform_now(post)

        expect(AttachImageJob).not_to have_been_enqueued.with(anything, result(11).image_url)
        expect(AttachImageJob).not_to have_been_enqueued.with(anything, result(12).image_url)
      end
    end

    context "when pages contain only already-collected pins" do
      before do
        (11..20).each { |id| create(:item, post:, url: result(id).url) }
        cursors = (1..10).to_h { |n| [ "b#{n}", page(11..20, cursor: "b#{n + 1}") ] }
        stub_pages(cursors)
      end

      it "gives up after #{described_class::MAX_PAGES} pages" do
        described_class.perform_now(post)

        expect(PinterestSearch).to have_received(:call).exactly(described_class::MAX_PAGES).times
      end
    end

    context "when the source runs out of pages" do
      before { stub_pages("b1" => page(11..13, cursor: nil)) }

      it "collects what is left and marks the post as exhausted" do
        expect { described_class.perform_now(post) }.to change(post.items, :count).by(3)
        expect(post.reload).to be_pins_exhausted
      end
    end
  end

  context "when the post's pins are exhausted" do
    let(:post) { create(:post, search_cursor: Post::END_CURSOR) }

    before { allow(PinterestSearch).to receive(:call) }

    it "does not search again" do
      described_class.perform_now(post)

      expect(PinterestSearch).not_to have_received(:call)
    end
  end

  describe "the post's collecting state" do
    let(:post) { create(:post, title: "cozy cabin", pins_requested_at: Time.current) }

    it "is cleared once collection finishes, refreshing pages showing the post" do
      stub_pages(nil => page(1..2, cursor: nil))
      post
      clear_enqueued_jobs

      described_class.perform_now(post)

      expect(post.reload).not_to be_collecting_pins
      expect(refresh_broadcasts_for(post)).to be >= 1
    end

    context "when the search fails" do
      before { allow(PinterestSearch).to receive(:call).and_raise(ImageSearch::Error) }

      it "is still cleared so the + tile stops spinning, and no items are created" do
        expect { described_class.perform_now(post) }.to raise_error(ImageSearch::Error)

        expect(post.reload).not_to be_collecting_pins
        expect(post.items).to be_empty
      end
    end

    context "when the post is deleted while collecting" do
      before do
        allow(PinterestSearch).to receive(:call) do
          Post.find(post.id).destroy!
          page([], cursor: nil)
        end
      end

      it "finishes without error" do
        expect { described_class.perform_now(post) }.not_to raise_error
        expect(Post.exists?(post.id)).to be(false)
      end
    end
  end
end
