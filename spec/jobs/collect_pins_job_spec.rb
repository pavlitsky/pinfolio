require "rails_helper"

RSpec.describe CollectPinsJob, type: :job do
  let(:post) { create(:post, title: "cozy cabin") }

  def result(id) = PinterestSearch::Result.new(url: "https://www.pinterest.com/pin/#{id}/", image_url: "https://i.pinimg.com/originals/#{id}.jpg")

  def page(ids, bookmark:) = PinterestSearch::Page.new(results: ids.map { |id| result(id) }, bookmark:)

  def stub_pages(pages)
    allow(PinterestSearch).to receive(:call) { |_query, bookmark:| pages.fetch(bookmark) }
  end

  describe "first collection" do
    before { stub_pages(nil => page(1..12, bookmark: "b1")) }

    it "searches Pinterest using the post title from the first page" do
      described_class.perform_now(post)

      expect(PinterestSearch).to have_received(:call).with("cozy cabin", bookmark: nil)
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

    it "saves the bookmark for the next collection" do
      described_class.perform_now(post)

      expect(post.reload.pinterest_bookmark).to eq("b1")
    end
  end

  describe "collecting more" do
    let(:post) { create(:post, title: "cozy cabin", pinterest_bookmark: "b1") }

    before { stub_pages("b1" => page(11..20, bookmark: "b2"), "b2" => page(21..30, bookmark: "b3")) }

    it "continues from the saved bookmark" do
      described_class.perform_now(post)

      expect(PinterestSearch).to have_received(:call).with("cozy cabin", bookmark: "b1")
      expect(post.items.pluck(:url)).to eq((11..20).map { |id| result(id).url })
      expect(post.reload.pinterest_bookmark).to eq("b2")
    end

    context "when results duplicate existing items, including hidden ones" do
      before do
        create(:item, post:, url: result(11).url)
        create(:item, post:, url: result(12).url, hidden_at: Time.current)
      end

      it "skips them and keeps paging until 10 new items are collected" do
        expect { described_class.perform_now(post) }.to change(post.items, :count).by(10)

        expect(post.items.pluck(:url)).to eq(([ 11, 12 ] + (13..22).to_a).map { |id| result(id).url })
        expect(post.reload.pinterest_bookmark).to eq("b3")
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
        bookmarks = (1..10).to_h { |n| [ "b#{n}", page(11..20, bookmark: "b#{n + 1}") ] }
        stub_pages(bookmarks)
      end

      it "gives up after #{described_class::MAX_PAGES} pages" do
        described_class.perform_now(post)

        expect(PinterestSearch).to have_received(:call).exactly(described_class::MAX_PAGES).times
      end
    end

    context "when Pinterest runs out of pages" do
      before { stub_pages("b1" => page(11..13, bookmark: PinterestSearch::END_BOOKMARK)) }

      it "collects what is left and marks the post as exhausted" do
        expect { described_class.perform_now(post) }.to change(post.items, :count).by(3)
        expect(post.reload).to be_pins_exhausted
      end
    end
  end

  context "when the post's pins are exhausted" do
    let(:post) { create(:post, pinterest_bookmark: PinterestSearch::END_BOOKMARK) }

    before { allow(PinterestSearch).to receive(:call) }

    it "does not search again" do
      described_class.perform_now(post)

      expect(PinterestSearch).not_to have_received(:call)
    end
  end

  describe "refreshing the page" do
    include Turbo::Broadcastable::TestHelper

    it "broadcasts the post once collection finishes" do
      stub_pages(nil => page(1..2, bookmark: PinterestSearch::END_BOOKMARK))

      streams = capture_turbo_stream_broadcasts(post) { described_class.perform_now(post) }

      expect(streams.map { |stream| [ stream["action"], stream["target"] ] }).to eq([ [ "replace", ActionView::RecordIdentifier.dom_id(post) ] ])
    end

    context "when the search fails" do
      before { allow(PinterestSearch).to receive(:call).and_raise(PinterestSearch::Error) }

      it "still broadcasts the post so the Add More tile resets, and creates no items" do
        streams = capture_turbo_stream_broadcasts(post) do
          expect { described_class.perform_now(post) }.to raise_error(PinterestSearch::Error)
        end

        expect(streams.size).to eq(1)
        expect(post.items).to be_empty
      end
    end
  end
end
