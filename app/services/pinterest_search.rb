# Searches Pinterest pins via the unofficial JSON endpoint used by pinterest.com.
# Undocumented and may change at any time; meant for occasional, manual use only.
class PinterestSearch
  # Bookmark Pinterest returns once there are no more pages
  END_BOOKMARK = "-end-".freeze
  PAGE_SIZE = 25

  ENDPOINT = URI("https://www.pinterest.com/resource/BaseSearchResource/get/")
  PIN_URL = "https://www.pinterest.com/pin/%s/".freeze
  IMAGE_SIZES = %w[orig 736x 474x].freeze
  HEADERS = {
    "X-Requested-With" => "XMLHttpRequest",
    "X-Pinterest-PWS-Handler" => "www/search/[scope].js"
  }.freeze

  # Returns one page of results; the cursor is Pinterest's bookmark for the next page.
  def self.call(query, cursor: nil) = new(query, cursor:).call

  def initialize(query, cursor: nil)
    @query = query
    @cursor = cursor
  end

  def call
    response = ImageSearch.get_json(request_uri, HEADERS)["resource_response"] || {}
    bookmark = response["bookmark"].presence
    ImageSearch::Page.new(
      results: (response.dig("data", "results") || []).filter_map { |pin| to_result(pin) },
      cursor: (bookmark unless bookmark == END_BOOKMARK)
    )
  end

  private
    def request_uri
      options = { query: @query, scope: "pins", page_size: PAGE_SIZE, bookmarks: [ @cursor ].compact }
      data = { options:, context: {} }
      params = { source_url: "/search/pins/?q=#{ERB::Util.url_encode(@query)}", data: data.to_json }
      ENDPOINT.dup.tap { |uri| uri.query = URI.encode_www_form(params) }
    end

    def to_result(pin)
      return unless pin["type"] == "pin" && !pin["is_promoted"]

      image_url = IMAGE_SIZES.lazy.filter_map { |size| pin.dig("images", size, "url") }.first
      ImageSearch::Result.new(url: format(PIN_URL, pin["id"]), image_url:) if image_url
    end
end
