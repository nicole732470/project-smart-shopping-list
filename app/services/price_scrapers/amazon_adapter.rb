module PriceScrapers
  # Amazon-specific adapter. Amazon's product detail pages don't always emit
  # complete schema.org Product JSON-LD, and they aggressively rate-limit
  # bots, so we go straight for the price/title/image elements that are
  # actually present in the rendered HTML.
  #
  # NOTE: Amazon's Terms of Service forbid scraping. This is acceptable for
  # a class project at our usage level (a handful of products, refreshed at
  # most once an hour), but should not be used at scale. Failures are caught
  # and surfaced via product.last_fetch_error rather than crashing.
  class AmazonAdapter < Base
    AMAZON_USER_AGENT =
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
      "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

    def user_agent
      AMAZON_USER_AGENT
    end

    PRICE_SELECTORS = [
      "#corePriceDisplay_desktop_feature_div .a-price .a-offscreen",
      "#corePrice_feature_div .a-price .a-offscreen",
      "#priceblock_ourprice",
      "#priceblock_dealprice",
      "#priceblock_saleprice",
      "span.a-price > span.a-offscreen",
    ].freeze

    TITLE_SELECTORS = [
      "#productTitle",
      "#title",
    ].freeze

    IMAGE_SELECTORS = [
      "#landingImage",
      "#imgBlkFront",
      "#main-image",
    ].freeze

    def parse(doc, _url)
      Result.new(
        price:     extract_price(doc),
        currency:  "USD",
        title:     extract_title(doc),
        image_url: extract_image(doc),
        store_name: "Amazon",
      )
    end

    private

    def extract_price(doc)
      PRICE_SELECTORS.each do |sel|
        node = doc.at_css(sel)
        next unless node
        price = parse_price(node.text)
        return price if price
      end
      nil
    end

    def extract_title(doc)
      TITLE_SELECTORS.each do |sel|
        node = doc.at_css(sel)
        return node.text.strip if node && !node.text.strip.empty?
      end
      nil
    end

    def extract_image(doc)
      IMAGE_SELECTORS.each do |sel|
        node = doc.at_css(sel)
        next unless node
        # Amazon often stores the high-res image url in data-old-hires
        # and a JSON map of resolutions in data-a-dynamic-image.
        url = node["data-old-hires"].presence ||
              node["src"].presence ||
              first_dynamic_image(node["data-a-dynamic-image"])
        return url if url.present?
      end
      nil
    end

    def first_dynamic_image(json)
      return nil if json.blank?
      parsed = JSON.parse(json)
      parsed.is_a?(Hash) ? parsed.keys.first : nil
    rescue JSON::ParserError
      nil
    end
  end
end
