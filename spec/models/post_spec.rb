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
end
