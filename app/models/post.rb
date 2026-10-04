class Post < ApplicationRecord
  has_many :items, -> { order(:id) }, dependent: :destroy

  validates :title, presence: true

  # A renamed post searches Pinterest for its new title from the first page;
  # already-collected (and hidden) pins are still skipped as duplicates
  before_update :restart_pinterest_search, if: :will_save_change_to_title?

  # Collects the next batch of pins, continuing from pinterest_bookmark
  def collect_pins_later = CollectPinsJob.perform_later(self)

  def pins_exhausted? = pinterest_bookmark == PinterestSearch::END_BOOKMARK

  # Ids of the items shown in the post's grid, in grid order
  def gallery_item_ids = items.visible.joins(:image_attachment).ids

  # Counts in Ruby so preloaded items (posts index) don't trigger another query
  def hidden_items_count = items.to_a.count(&:hidden?)

  private
    def restart_pinterest_search
      self.pinterest_bookmark = nil
    end
end
