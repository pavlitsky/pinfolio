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
    data, content_type = download(uri)
    image = WebImage.call(data, content_type:, filename: File.basename(uri.path))

    # Attaching touches the item and its post, which refreshes pages showing the post
    item.image.attach(io: StringIO.new(image.data), filename: image.filename, content_type: image.content_type)
  end

  private
    # Streams the body so an oversized image is rejected without reading it all into memory
    def download(uri)
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 5, read_timeout: 15) do |http|
        http.request_get(uri.request_uri) do |response|
          raise DownloadError, "#{uri} responded with HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)
          raise DownloadError, "#{uri} is not an image" unless response.content_type&.start_with?("image/")
          raise DownloadError, "#{uri} is larger than #{MAX_SIZE} bytes" if response.content_length.to_i > MAX_SIZE

          data = String.new # binary
          response.read_body do |chunk|
            data << chunk
            raise DownloadError, "#{uri} is larger than #{MAX_SIZE} bytes" if data.bytesize > MAX_SIZE
          end
          return [ data, response.content_type ]
        end
      end
    end
end
