class Post < ApplicationRecord
  has_many :items, -> { order(:id) }, dependent: :destroy

  validates :title, presence: true

  # Collects the next batch of pins, continuing from pinterest_bookmark
  def collect_pins_later = CollectPinsJob.perform_later(self)

  def pins_exhausted? = pinterest_bookmark == PinterestSearch::END_BOOKMARK
end
