class Item < ApplicationRecord
  belongs_to :post
  has_one_attached :image

  # Hidden items stay in the database so their urls are skipped when collecting more pins
  scope :visible, -> { where(hidden_at: nil) }
  scope :hidden, -> { where.not(hidden_at: nil) }

  # Anchored so the whole value must be an http(s) url; it is rendered as a link href
  URL_FORMAT = /\A#{URI::DEFAULT_PARSER.make_regexp(%w[http https])}\z/

  validates :url, presence: true, format: { with: URL_FORMAT, allow_blank: true }
  validates :url, uniqueness: { scope: :post_id }
  validates :position, numericality: { only_integer: true }

  # New items go to the end of their post's grid
  before_validation :append_to_post, on: :create

  def hidden? = hidden_at.present?

  def hide! = update!(hidden_at: Time.current)

  def unhide! = update!(hidden_at: nil)

  private
    def append_to_post
      self.position ||= (Item.where(post_id:).maximum(:position) || 0) + 1
    end
end
