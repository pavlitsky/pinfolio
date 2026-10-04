require "rails_helper"

RSpec.describe Item, type: :model do
  describe "validations" do
    it "is valid with a post and an http(s) url" do
      expect(build(:item)).to be_valid
    end

    context "without a post" do
      it "is invalid" do
        item = build(:item, post: nil)

        expect(item).not_to be_valid
        expect(item.errors[:post]).to include("must exist")
      end
    end

    context "without a url" do
      it "is invalid" do
        item = build(:item, url: "")

        expect(item).not_to be_valid
        expect(item.errors[:url]).to include("can't be blank")
      end
    end

    context "with a malformed url" do
      %w[not-a-url ftp://example.com/image.jpg javascript:alert(1)].each do |url|
        it "rejects #{url.inspect}" do
          item = build(:item, url:)

          expect(item).not_to be_valid
          expect(item.errors[:url]).to include("is invalid")
        end
      end
    end
  end

  describe "url uniqueness" do
    let(:existing) { create(:item) }

    context "within the same post" do
      it "is invalid" do
        item = build(:item, post: existing.post, url: existing.url)

        expect(item).not_to be_valid
        expect(item.errors[:url]).to include("has already been taken")
      end
    end

    context "in another post" do
      it "is valid" do
        expect(build(:item, url: existing.url)).to be_valid
      end
    end
  end

  describe "database constraints" do
    it "rejects a NULL url" do
      expect { build(:item, url: nil).save!(validate: false) }.to raise_error(ActiveRecord::NotNullViolation)
    end

    it "rejects a duplicate url within the same post" do
      existing = create(:item)

      expect { build(:item, post: existing.post, url: existing.url).save!(validate: false) }
        .to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe "hiding" do
    let(:item) { create(:item) }

    it "is visible by default" do
      expect(item).not_to be_hidden
      expect(Item.visible).to include(item)
    end

    it "#unhide! makes a hidden item visible again" do
      item.hide!
      item.unhide!

      expect(item.reload).not_to be_hidden
      expect(Item.visible).to include(item)
    end

    it ".hidden returns only hidden items" do
      hidden = create(:item, hidden_at: Time.current)

      expect(Item.hidden).to eq([ hidden ])
    end

    it "#hide! hides the item but keeps it in the database" do
      item.hide!

      expect(item.reload).to be_hidden
      expect(Item.visible).not_to include(item)
      expect(Item.exists?(item.id)).to be(true)
    end
  end

  describe "image attachment" do
    let(:item) { create(:item) }

    it "has no image by default" do
      expect(item.image).not_to be_attached
    end

    it "can attach an image" do
      item.image.attach(io: StringIO.new("fake image"), filename: "image.jpg", content_type: "image/jpeg")

      expect(item.image).to be_attached
    end
  end
end
