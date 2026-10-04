require "net/http"

# Downloads an image from a remote url and attaches it to the item, converting
# formats browsers can't display (e.g. HEIC) to JPEG.
class AttachImageJob < ApplicationJob
  class DownloadError < StandardError; end

  MAX_SIZE = 20.megabytes

  queue_as :default

  retry_on Net::OpenTimeout, Net::ReadTimeout, wait: 5.seconds, attempts: 3
  discard_on DownloadError, WebImage::Error

  def perform(item, image_url)
    uri = URI(image_url)
    response = Net::HTTP.get_response(uri)
    raise DownloadError, "#{image_url} responded with HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)
    raise DownloadError, "#{image_url} is not an image" unless response.content_type&.start_with?("image/")
    raise DownloadError, "#{image_url} is larger than #{MAX_SIZE} bytes" if response.body.bytesize > MAX_SIZE

    image = WebImage.call(response.body, content_type: response.content_type, filename: File.basename(uri.path))

    # Attaching touches the item and its post, which refreshes pages showing the post
    item.image.attach(io: StringIO.new(image.data), filename: image.filename, content_type: image.content_type)
  end
end
