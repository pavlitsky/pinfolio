# Searches Flickr photos via the official flickr.photos.search REST method, authenticated
# with the public "site key" flickr.com embeds in its own pages (no API key of our own).
# The site key rotates, so it's cached and re-scraped when Flickr rejects it.
class FlickrSearch
  PAGE_SIZE = 25

  ENDPOINT = URI("https://api.flickr.com/services/rest")
  SEARCH_PAGE = URI("https://www.flickr.com/search/")
  SITE_KEY_PATTERN = /flickr\.api\.site_key\s*=\s*"(\h+)"/
  SITE_KEY_CACHE_KEY = "flickr_search/site_key".freeze
  # flickr.com itself refetches the key hourly (site_key_fetch_interval)
  SITE_KEY_TTL = 1.hour
  INVALID_KEY_CODE = 100

  PHOTO_URL = "https://www.flickr.com/photos/%s/%s/".freeze
  # Largest first, from 2048px down; the larger sizes aren't available for every photo
  IMAGE_SIZES = %w[url_k url_h url_l url_c url_z].freeze

  # Returns one page of results; the cursor is the next page number.
  def self.call(query, cursor: nil) = new(query, cursor:).call

  def initialize(query, cursor: nil)
    @query = query
    @page = [ cursor.to_i, 1 ].max
  end

  def call
    photos = search.fetch("photos")
    more = photos["page"].to_i < photos["pages"].to_i && photos["photo"].present?
    ImageSearch::Page.new(
      results: photos["photo"].to_a.filter_map { |photo| to_result(photo) },
      cursor: ((@page + 1).to_s if more)
    )
  end

  private
    def search(retry_with_new_key: true)
      response = ImageSearch.get_json(request_uri(site_key))
      return response unless response["stat"] == "fail"

      if response["code"] == INVALID_KEY_CODE && retry_with_new_key
        Rails.cache.delete(SITE_KEY_CACHE_KEY)
        return search(retry_with_new_key: false)
      end
      raise ImageSearch::Error, "Flickr search failed: #{response['message']}"
    end

    def site_key
      Rails.cache.fetch(SITE_KEY_CACHE_KEY, expires_in: SITE_KEY_TTL) do
        ImageSearch.get(SEARCH_PAGE)[SITE_KEY_PATTERN, 1] or raise ImageSearch::Error, "Flickr site key not found"
      end
    end

    def request_uri(api_key)
      params = {
        method: "flickr.photos.search", api_key:, text: @query, page: @page, per_page: PAGE_SIZE,
        sort: "relevance", media: "photos", safe_search: 1, extras: IMAGE_SIZES.join(","),
        format: "json", nojsoncallback: 1
      }
      ENDPOINT.dup.tap { |uri| uri.query = URI.encode_www_form(params) }
    end

    def to_result(photo)
      image_url = IMAGE_SIZES.lazy.filter_map { |size| photo[size] }.first
      ImageSearch::Result.new(url: format(PHOTO_URL, photo["owner"], photo["id"]), image_url:) if image_url
    end
end
