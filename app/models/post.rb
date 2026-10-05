class Post < ApplicationRecord
  # Pin collection running longer than this is treated as finished (e.g. its job was lost)
  PINS_REQUEST_TIMEOUT = 2.minutes
  # Saved as the search cursor once the source has no more pages
  END_CURSOR = "-end-".freeze
  SEARCHES = { "pinterest" => PinterestSearch, "flickr" => FlickrSearch }.freeze

  # Where the post's images are collected from
  enum :source, { pinterest: "pinterest", flickr: "flickr" }, default: :pinterest, validate: true

  has_many :items, -> { order(:position, :id) }, dependent: :destroy

  # Pages showing a post morph-refresh when it (or, via touch, one of its items) changes;
  # new posts refresh pages subscribed to "posts"
  broadcasts_refreshes

  validates :title, presence: true

  # A renamed post searches its source for the new title from the first page;
  # already-collected (and hidden) pins are still skipped as duplicates
  before_update :restart_search, if: :will_save_change_to_title?

  # Collects the next batch of pins, continuing from search_cursor
  def collect_pins_later
    update!(pins_requested_at: Time.current)
    CollectPinsJob.perform_later(self)
  end

  def collecting_pins? = pins_requested_at.present? && pins_requested_at.after?(PINS_REQUEST_TIMEOUT.ago)

  def pins_exhausted? = search_cursor == END_CURSOR

  def search = SEARCHES.fetch(source)

  # "Pinterest", "Flickr"
  def source_name = self.class.source_name(source)

  def self.source_name(source) = source.to_s.capitalize

  # Ids of the items shown in the post's grid, in grid order
  def gallery_item_ids = items.visible.joins(:image_attachment).ids

  # Counts in Ruby so preloaded items (posts index) don't trigger another query
  def hidden_items_count = items.to_a.count(&:hidden?)

  # Reorders the given items (e.g. the visible ones after a drag) by reusing their
  # current positions in the new order, so items left out (hidden ones) keep their slots.
  # Ids that don't belong to this post are ignored.
  def reorder_items!(ids)
    moved = items.where(id: ids).index_by(&:id)
    ordered = ids.map(&:to_i).uniq.filter_map { |id| moved[id] }
    slots = ordered.map(&:position).sort

    transaction do
      ordered.zip(slots).each { |item, position| item.update!(position:) }
    end
  end

  private
    def restart_search
      self.search_cursor = nil
    end
end
