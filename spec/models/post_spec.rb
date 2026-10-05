require "rails_helper"

RSpec.describe Post, type: :model do
  describe "validations" do
    it "is valid with a title" do
      expect(build(:post)).to be_valid
    end

    context "without a title" do
      it "is invalid" do
        post = build(:post, title: "")

        expect(post).not_to be_valid
        expect(post.errors[:title]).to include("can't be blank")
      end
    end
  end

  describe "source" do
    it "defaults to Pinterest" do
      expect(build(:post)).to be_pinterest
    end

    it "can be Flickr" do
      expect(build(:post, source: :flickr)).to be_valid
    end

    it "is invalid when unknown" do
      post = build(:post, source: "instagram")

      expect(post).not_to be_valid
      expect(post.errors[:source]).to include("is not included in the list")
    end
  end

  describe "database constraints" do
    it "rejects a NULL title" do
      expect { build(:post, title: nil).save!(validate: false) }.to raise_error(ActiveRecord::NotNullViolation)
    end

    it "rejects an unknown source" do
      post = create(:post)

      expect { post.update_column(:source, "instagram") }.to raise_error(ActiveRecord::StatementInvalid, /CHECK constraint/)
    end
  end

  describe "associations" do
    let(:post) { create(:post) }

    it "has many items" do
      items = create_list(:item, 2, post:)

      expect(post.items).to match_array(items)
    end

    context "when destroyed" do
      it "destroys its items" do
        create_list(:item, 2, post:)

        expect { post.destroy }.to change(Item, :count).by(-2)
      end
    end
  end

  describe "#collect_pins_later" do
    let(:post) { create(:post) }

    it "enqueues a job collecting pins for the post" do
      expect { post.collect_pins_later }.to have_enqueued_job(CollectPinsJob).with(post)
    end

    it "marks the post as collecting pins" do
      post.collect_pins_later

      expect(post.reload).to be_collecting_pins
    end
  end

  describe "#collecting_pins?" do
    it "is false when no collection was requested" do
      expect(build(:post)).not_to be_collecting_pins
    end

    it "is true while a recent request is pending" do
      expect(build(:post, pins_requested_at: 10.seconds.ago)).to be_collecting_pins
    end

    it "is false once the request is older than the timeout (e.g. the job was lost)" do
      expect(build(:post, pins_requested_at: (Post::PINS_REQUEST_TIMEOUT + 1.second).ago)).not_to be_collecting_pins
    end
  end

  describe "page refresh broadcasts" do
    let!(:post) { create(:post) }

    before { clear_enqueued_jobs }

    it "refreshes the posts list when a post is created" do
      create(:post)

      expect(refresh_broadcasts_for("posts")).to eq(1)
    end

    it "refreshes pages showing the post when it changes" do
      post.update!(title: "renamed")

      expect(refresh_broadcasts_for(post)).to eq(1)
    end

    it "refreshes pages showing the post when one of its items changes" do
      item = create(:item, post:)
      clear_enqueued_jobs

      item.hide!

      expect(refresh_broadcasts_for(post)).to eq(1)
    end
  end

  describe "#pins_exhausted?" do
    it "is false before any collection" do
      expect(build(:post)).not_to be_pins_exhausted
    end

    it "is false while the source has more pages" do
      expect(build(:post, search_cursor: "abc")).not_to be_pins_exhausted
    end

    it "is true once the source has no more pages" do
      expect(build(:post, search_cursor: Post::END_CURSOR)).to be_pins_exhausted
    end
  end

  describe "#search" do
    it "is the search service of the post's source" do
      expect(build(:post).search).to eq(PinterestSearch)
      expect(build(:post, source: :flickr).search).to eq(FlickrSearch)
    end
  end

  describe "#source_name" do
    it "is the source's display name" do
      expect(build(:post).source_name).to eq("Pinterest")
      expect(build(:post, source: :flickr).source_name).to eq("Flickr")
    end
  end

  describe "#items" do
    it "are ordered by creation, oldest first" do
      post = create(:post)
      first = create(:item, post:)
      second = create(:item, post:)

      expect(post.reload.items).to eq([ first, second ])
    end
  end

  describe "#hidden_items_count" do
    it "counts only hidden items" do
      post = create(:post)
      create(:item, post:)
      create_list(:item, 2, post:, hidden_at: Time.current)

      expect(post.hidden_items_count).to eq(2)
    end
  end

  describe "#gallery_item_ids" do
    it "lists visible items with images, in grid order" do
      post = create(:post)
      attach = ->(item) { item.image.attach(io: StringIO.new("x"), filename: "a.jpg", content_type: "image/jpeg") }
      first = create(:item, post:).tap(&attach)
      create(:item, post:, hidden_at: Time.current).tap(&attach)
      create(:item, post:)
      last = create(:item, post:).tap(&attach)

      expect(post.gallery_item_ids).to eq([ first.id, last.id ])
    end
  end

  describe "renaming" do
    let(:post) { create(:post, title: "cozy cabin", search_cursor: "b3") }

    it "restarts the search when the title changes" do
      post.update!(title: "snowy cabin")

      expect(post.reload.search_cursor).to be_nil
    end

    it "keeps the search position when other attributes change" do
      post.update!(search_cursor: "b4")

      expect(post.reload.search_cursor).to eq("b4")
    end

    it "keeps the search position when the title is saved unchanged" do
      post.update!(title: "cozy cabin")

      expect(post.reload.search_cursor).to eq("b3")
    end
  end

  describe "#reorder_items!" do
    let(:post) { create(:post) }
    let!(:items) { create_list(:item, 4, post:) }

    it "saves the given order" do
      post.reorder_items!(items.reverse.map(&:id))

      expect(post.reload.items).to eq(items.reverse)
    end

    it "keeps items left out (hidden ones) in their slots" do
      items[1].hide!
      visible = [ items[0], items[2], items[3] ]

      post.reorder_items!([ items[3], items[0], items[2] ].map(&:id))

      expect(post.reload.items).to eq([ items[3], items[1], items[0], items[2] ])
      expect(post.items.visible).to eq([ items[3], items[0], items[2] ])
      expect(visible.map { |item| item.reload.position }.sort).to eq([ 1, 3, 4 ])
    end

    it "accepts ids as strings, as they arrive from a request" do
      post.reorder_items!(items.reverse.map { |item| item.id.to_s })

      expect(post.reload.items).to eq(items.reverse)
    end

    it "ignores ids of other posts' items" do
      other_item = create(:item)

      expect { post.reorder_items!([ other_item.id, *items.reverse.map(&:id) ]) }.not_to change { other_item.reload.position }
      expect(post.reload.items).to eq(items.reverse)
    end
  end
end
