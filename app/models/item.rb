class Item < ApplicationRecord
  belongs_to :post
  has_one_attached :image

  # Hidden items stay in the database so their urls are skipped when collecting more pins
  scope :visible, -> { where(hidden_at: nil) }

  validates :url, presence: true, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), allow_blank: true }
  validates :url, uniqueness: { scope: :post_id }

  def hidden? = hidden_at.present?

  def hide! = update!(hidden_at: Time.current)
end
