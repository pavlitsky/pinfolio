# Searches the post's source for its title, continuing from the post's saved cursor,
# and creates up to `limit` new items, skipping urls the post already has (hidden ones too).
# Each new item's image is downloaded in a separate job.
class CollectPinsJob < ApplicationJob
  # Stop paging when a search keeps returning only already-collected pins
  MAX_PAGES = 5

  queue_as :default

  def perform(post, limit: 10)
    collected = 0

    MAX_PAGES.times do
      break if post.pins_exhausted?

      page = post.search.call(post.title, cursor: post.search_cursor)
      page.results.each do |result|
        break if collected >= limit

        item = add_item(post, result.url)
        next unless item

        AttachImageJob.perform_later(item, result.image_url)
        collected += 1
      end
      post.update!(search_cursor: page.cursor || Post::END_CURSOR)

      break if collected >= limit
    end
  ensure
    # Ends the "+" tile's loading state (and refreshes pages showing the post), even on failure
    post.update!(pins_requested_at: nil) if Post.exists?(post.id)
  end

  private
    # Built outside post.items so a rejected duplicate doesn't linger in the loaded
    # association and fail validation when the post is saved
    def add_item(post, url)
      item = Item.create(post_id: post.id, url:)
      item if item.persisted?
    rescue ActiveRecord::RecordNotUnique
      # Collected concurrently by another job
      nil
    end
end
