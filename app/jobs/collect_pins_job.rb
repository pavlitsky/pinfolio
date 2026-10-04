# Searches Pinterest for the post's title and creates an item per result,
# then downloads each result's image in a separate job.
class CollectPinsJob < ApplicationJob
  queue_as :default

  def perform(post, limit: 10)
    PinterestSearch.call(post.title, limit:).each do |result|
      item = post.items.create!(url: result.url)
      AttachImageJob.perform_later(item, result.image_url)
    end
  end
end
