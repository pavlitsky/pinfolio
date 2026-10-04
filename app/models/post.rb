class Post < ApplicationRecord
  has_many :items, dependent: :destroy

  validates :title, presence: true

  def collect_pins_later = CollectPinsJob.perform_later(self)
end
