require "rails_helper"

RSpec.describe WebImage do
  describe ".call" do
    context "when browsers can display the format" do
      it "keeps the image as is" do
        data = file_fixture("image.jpg").binread

        result = described_class.call(data, content_type: "image/jpeg", filename: "photo.jpg")

        expect(result).to have_attributes(data:, content_type: "image/jpeg", filename: "photo.jpg")
      end
    end

    context "when the image is HEIC" do
      let(:data) { file_fixture("photo.heic").binread }

      it "converts it to JPEG" do
        result = described_class.call(data, content_type: "image/heic", filename: "photo.heic")

        expect(result.content_type).to eq("image/jpeg")
        expect(result.filename).to eq("photo.jpg")
        expect(Vips::Image.new_from_buffer(result.data, "").get("vips-loader")).to eq("jpegload_buffer")
      end

      it "keeps the dimensions" do
        result = described_class.call(data, content_type: "image/heic", filename: "photo.heic")

        image = Vips::Image.new_from_buffer(result.data, "")
        expect([ image.width, image.height ]).to eq([ 32, 24 ])
      end
    end

    context "when the data can't be decoded" do
      it "raises an error" do
        expect { described_class.call("not an image", content_type: "image/heic", filename: "photo.heic") }
          .to raise_error(WebImage::Error, /photo\.heic \(image\/heic\) could not be converted/)
      end
    end
  end
end
