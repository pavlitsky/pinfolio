require "net/http"

# Downloads an image from a remote url, attaches it to the item and
# refreshes the item's post for anyone viewing it.
class AttachImageJob < ApplicationJob
  class DownloadError < StandardError; end

  MAX_SIZE = 20.megabytes

  queue_as :default

  retry_on Net::OpenTimeout, Net::ReadTimeout, wait: 5.seconds, attempts: 3
  discard_on DownloadError

  def perform(item, image_url)
    uri = URI(image_url)
    response = Net::HTTP.get_response(uri)
    raise DownloadError, "#{image_url} responded with HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)
    raise DownloadError, "#{image_url} is not an image" unless response.content_type&.start_with?("image/")
    raise DownloadError, "#{image_url} is larger than #{MAX_SIZE} bytes" if response.body.bytesize > MAX_SIZE

    item.image.attach(io: StringIO.new(response.body), filename: File.basename(uri.path), content_type: response.content_type)
    item.post.broadcast_replace_to item.post, partial: "posts/post", locals: { post: item.post }
  end
end
