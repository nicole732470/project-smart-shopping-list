require "cgi"

# Finds similar products within a budget using the UPC Item DB search API.
# Returns items sorted by price ascending, each with the cheapest available
# offer that fits the budget.
class ProductRecommender
  API_URL    = "https://api.upcitemdb.com/prod/trial/search"
  MAX_ITEMS  = 6

  Recommendation = Struct.new(
    :name, :price, :image_url, :store_name, :url,
    keyword_init: true
  )

  def initialize(product, budget)
    @product = product
    @budget  = budget.to_f
  end

  def call
    items = search_api
    results = []

    items.each do |item|
      break if results.size >= MAX_ITEMS

      # Skip items whose name is identical to the source product
      next if item["title"].to_s.strip.casecmp?(@product.name.to_s.strip)

      best = cheapest_offer_within_budget(item["offers"])
      next unless best

      results << Recommendation.new(
        name:       item["title"].presence || best["title"],
        price:      best["price"].to_f,
        image_url:  item["images"]&.first,
        store_name: best["merchant"],
        url:        best["link"]
      )
    end

    results.sort_by(&:price)
  end

  private

  def search_api
    query    = CGI.escape(@product.name)
    response = HTTParty.get(
      "#{API_URL}?s=#{query}&type=product",
      headers: { "User-Agent" => "SmartShoppingList/1.0", "Accept" => "application/json" },
      timeout: 10
    )
    return [] unless response.code == 200

    response.parsed_response["items"].to_a
  rescue => e
    Rails.logger.warn("[ProductRecommender] UPC API error: #{e.message}")
    []
  end

  def cheapest_offer_within_budget(offers)
    Array(offers)
      .select { |o| o["price"].to_f > 0 && o["price"].to_f <= @budget && o["link"].present? }
      .min_by { |o| o["price"].to_f }
  end
end
