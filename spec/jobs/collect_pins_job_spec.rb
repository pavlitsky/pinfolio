require "rails_helper"

RSpec.describe CollectPinsJob, type: :job do
  let(:post) { create(:post, title: "cozy cabin") }
  let(:results) do
    [
      PinterestSearch::Result.new(url: "https://www.pinterest.com/pin/1/", image_url: "https://i.pinimg.com/originals/1.jpg"),
      PinterestSearch::Result.new(url: "https://www.pinterest.com/pin/2/", image_url: "https://i.pinimg.com/originals/2.jpg")
    ]
  end

  before { allow(PinterestSearch).to receive(:call).and_return(results) }

  it "searches Pinterest using the post title" do
    described_class.perform_now(post)

    expect(PinterestSearch).to have_received(:call).with("cozy cabin", limit: 10)
  end

  it "creates an item per result linking to the pin" do
    expect { described_class.perform_now(post) }.to change(post.items, :count).by(2)
    expect(post.items.pluck(:url)).to eq(results.map(&:url))
  end

  it "enqueues an image download per item" do
    described_class.perform_now(post)

    post.items.zip(results).each do |item, result|
      expect(AttachImageJob).to have_been_enqueued.with(item, result.image_url)
    end
  end

  context "when the search fails" do
    before { allow(PinterestSearch).to receive(:call).and_raise(PinterestSearch::Error) }

    it "creates no items" do
      expect { described_class.perform_now(post) rescue nil }.not_to change(Item, :count)
    end
  end
end
