# Searches Pinterest for the post's title, continuing from the post's saved bookmark,
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

      page = PinterestSearch.call(post.title, bookmark: post.pinterest_bookmark)
      page.results.each do |result|
        break if collected >= limit

        item = add_item(post, result.url)
        next unless item

        AttachImageJob.perform_later(item, result.image_url)
        collected += 1
      end
      post.update!(pinterest_bookmark: page.bookmark.presence || PinterestSearch::END_BOOKMARK)

      break if collected >= limit
    end
  ensure
    # Re-render the post so the "Add More" tile leaves its loading state, even on failure
    refresh(post)
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

    def refresh(post)
      return unless Post.exists?(post.id)

      post.reload.broadcast_replace_to post, partial: "posts/post", locals: { post: }
    end
end
