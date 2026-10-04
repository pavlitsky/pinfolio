class Item < ApplicationRecord
  belongs_to :post
  has_one_attached :image

  validates :url, presence: true, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), allow_blank: true }
end
