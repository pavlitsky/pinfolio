require "net/http"

# Searches Pinterest pins via the unofficial JSON endpoint used by pinterest.com.
# Undocumented and may change at any time; meant for occasional, manual use only.
class PinterestSearch
  class Error < StandardError; end

  Result = Data.define(:url, :image_url)

  ENDPOINT = URI("https://www.pinterest.com/resource/BaseSearchResource/get/")
  PIN_URL = "https://www.pinterest.com/pin/%s/".freeze
  IMAGE_SIZES = %w[orig 736x 474x].freeze
  HEADERS = {
    "Accept" => "application/json",
    "X-Requested-With" => "XMLHttpRequest",
    "X-Pinterest-PWS-Handler" => "www/search/[scope].js",
    "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0 Safari/537.36"
  }.freeze

  def self.call(query, limit: 10) = new(query, limit:).call

  def initialize(query, limit: 10)
    @query = query
    @limit = limit
  end

  def call
    pins.filter_map { |pin| to_result(pin) }.first(@limit)
  end

  private
    def pins
      response = Net::HTTP.start(ENDPOINT.host, ENDPOINT.port, use_ssl: true, open_timeout: 5, read_timeout: 10) do |http|
        http.get(request_uri, HEADERS)
      end
      raise Error, "Pinterest responded with HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body).dig("resource_response", "data", "results") || []
    rescue JSON::ParserError, Net::OpenTimeout, Net::ReadTimeout, SocketError, SystemCallError, OpenSSL::SSL::SSLError => e
      raise Error, "Pinterest search failed: #{e.message}"
    end

    def request_uri
      data = { options: { query: @query, scope: "pins", page_size: [ @limit * 2, 25 ].min }, context: {} }
      params = { source_url: "/search/pins/?q=#{ERB::Util.url_encode(@query)}", data: data.to_json }
      "#{ENDPOINT.path}?#{URI.encode_www_form(params)}"
    end

    def to_result(pin)
      return unless pin["type"] == "pin" && !pin["is_promoted"]

      image_url = IMAGE_SIZES.lazy.filter_map { |size| pin.dig("images", size, "url") }.first
      Result.new(url: format(PIN_URL, pin["id"]), image_url:) if image_url
    end
end
