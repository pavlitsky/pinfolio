require "vips"

# Makes downloaded image data displayable in browsers: formats browsers render
# are kept as is, anything else (e.g. HEIC from iPhones) is converted to JPEG.
class WebImage
  class Error < StandardError; end

  Result = Data.define(:data, :content_type, :filename)

  BROWSER_TYPES = %w[image/jpeg image/png image/gif image/webp image/avif].freeze
  JPEG_QUALITY = 85

  def self.call(data, content_type:, filename:) = new(data, content_type:, filename:).call

  def initialize(data, content_type:, filename:)
    @data = data
    @content_type = content_type
    @filename = filename
  end

  def call
    return Result.new(data:, content_type:, filename:) if BROWSER_TYPES.include?(content_type)

    Result.new(data: to_jpeg, content_type: "image/jpeg", filename: "#{File.basename(filename, '.*')}.jpg")
  end

  private
    attr_reader :data, :content_type, :filename

    def to_jpeg
      image = Vips::Image.new_from_buffer(data, "").autorot
      image = image.flatten(background: 255) if image.has_alpha?
      image.jpegsave_buffer(Q: JPEG_QUALITY)
    rescue Vips::Error => e
      raise Error, "#{filename} (#{content_type}) could not be converted: #{e.message.lines.first&.strip}"
    end
end
