require "net/http"

# Shared pieces of the image searches (PinterestSearch, FlickrSearch). Each search is called
# as `call(query, cursor:)` and returns a Page; pass its cursor back to get the next page.
module ImageSearch
  class Error < StandardError; end

  Result = Data.define(:url, :image_url)
  # cursor is nil once there are no more pages
  Page = Data.define(:results, :cursor)

  USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0 Safari/537.36".freeze

  # GETs the uri and returns the response body, raising Error on network failures and non-2xx responses
  def self.get(uri, headers = {})
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 10) do |http|
      http.get(uri.request_uri, { "User-Agent" => USER_AGENT, **headers })
    end
    raise Error, "#{uri.host} responded with HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    response.body
  rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, SystemCallError, OpenSSL::SSL::SSLError => e
    raise Error, "#{uri.host} request failed: #{e.message}"
  end

  def self.get_json(uri, headers = {})
    JSON.parse(get(uri, { "Accept" => "application/json", **headers }))
  rescue JSON::ParserError => e
    raise Error, "#{uri.host} returned invalid JSON: #{e.message}"
  end
end
