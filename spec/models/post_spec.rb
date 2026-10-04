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

  describe "database constraints" do
    it "rejects a NULL title" do
      expect { build(:post, title: nil).save!(validate: false) }.to raise_error(ActiveRecord::NotNullViolation)
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
    it "enqueues a job collecting pins for the post" do
      post = create(:post)

      expect { post.collect_pins_later }.to have_enqueued_job(CollectPinsJob).with(post)
    end
  end

  describe "#pins_exhausted?" do
    it "is false before any collection" do
      expect(build(:post)).not_to be_pins_exhausted
    end

    it "is false while Pinterest has more pages" do
      expect(build(:post, pinterest_bookmark: "abc")).not_to be_pins_exhausted
    end

    it "is true once Pinterest has no more pages" do
      expect(build(:post, pinterest_bookmark: PinterestSearch::END_BOOKMARK)).to be_pins_exhausted
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
    let(:post) { create(:post, title: "cozy cabin", pinterest_bookmark: "b3") }

    it "restarts the Pinterest search when the title changes" do
      post.update!(title: "snowy cabin")

      expect(post.reload.pinterest_bookmark).to be_nil
    end

    it "keeps the search position when other attributes change" do
      post.update!(pinterest_bookmark: "b4")

      expect(post.reload.pinterest_bookmark).to eq("b4")
    end

    it "keeps the search position when the title is saved unchanged" do
      post.update!(title: "cozy cabin")

      expect(post.reload.pinterest_bookmark).to eq("b3")
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
