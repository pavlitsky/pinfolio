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
end
