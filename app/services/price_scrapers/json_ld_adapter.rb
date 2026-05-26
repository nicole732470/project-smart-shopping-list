require "json"

module PriceScrapers
  # Generic adapter for non-Amazon retailers. Tries structured data in order:
  #   1. schema.org JSON-LD (<script type="application/ld+json">)
  #   2. Open Graph / product meta tags (og:title, product:price:amount, …)
  #   3. HTML microdata (itemprop="price", itemtype Product, …)
  #
  # Most large retailers use JSON-LD; Shopify and smaller DTC sites often
  # expose only OG/meta tags. One adapter covers both without per-site code.
  #
  # Raises PermanentError only when no price could be extracted from any layer.
  class JsonLdAdapter < Base
    META_PRICE_KEYS = %w[
      product:price:amount
      og:price:amount
    ].freeze

    META_CURRENCY_KEYS = %w[
      product:price:currency
      og:price:currency
    ].freeze

    def parse(doc, url)
      result = merge_results(parse_json_ld(doc), parse_meta_tags(doc))
      result = merge_results(result, parse_microdata(doc))

      raise PermanentError, "No product price found on page" unless result&.price

      result
    end

    private

    def parse_json_ld(doc)
      products = collect_product_nodes(doc)
      return nil if products.empty?

      product = products.first
      offer   = first_offer(product)

      Result.new(
        price:     parse_price(offer&.dig("price") || offer&.dig("lowPrice")),
        currency: (offer&.dig("priceCurrency") || "USD"),
        title:     stringify(product["name"]),
        image_url: first_image(product["image"])
      )
    end

    def parse_meta_tags(doc)
      price = META_PRICE_KEYS.lazy.filter_map { |key| parse_price(meta_content(doc, key)) }.find(&:itself)
      return nil unless price

      Result.new(
        price:     price,
        currency:  meta_currency(doc) || "USD",
        title:     meta_content(doc, "og:title") || meta_content(doc, "twitter:title"),
        image_url: meta_content(doc, "og:image") || meta_content(doc, "twitter:image")
      )
    end

    def parse_microdata(doc)
      scope = doc.at_css('[itemtype*="schema.org/Product"], [itemtype*="schema.org/Offer"]')
      scope ||= doc.at_css('[itemprop="price"]')&.ancestors&.find { |node| node["itemscope"] }
      return nil unless scope

      price = parse_price(scope.at_css('[itemprop="price"]')&.[]("content") ||
                          scope.at_css('[itemprop="price"]')&.text)
      return nil unless price

      Result.new(
        price:     price,
        currency:  scope.at_css('[itemprop="priceCurrency"]')&.[]("content") || "USD",
        title:     scope.at_css('[itemprop="name"]')&.text&.strip,
        image_url: microdata_image(scope)
      )
    end

    def merge_results(primary, secondary)
      return secondary if primary.nil?
      return primary if secondary.nil?

      Result.new(
        price:     primary.price || secondary.price,
        currency:  primary.currency || secondary.currency || "USD",
        title:     primary.title || secondary.title,
        image_url: primary.image_url || secondary.image_url,
        store_name: primary.store_name || secondary.store_name
      )
    end

    def meta_content(doc, property)
      doc.at_css("meta[property='#{property}']")&.[]("content") ||
        doc.at_css("meta[name='#{property}']")&.[]("content")
    end

    def meta_currency(doc)
      META_CURRENCY_KEYS.lazy.filter_map { |key| meta_content(doc, key) }.find(&:present?)
    end

    def microdata_image(scope)
      node = scope.at_css('[itemprop="image"]')
      return nil unless node

      node["content"].presence || node["src"].presence || node["href"].presence
    end

    def collect_product_nodes(doc)
      nodes = []
      doc.css('script[type="application/ld+json"]').each do |tag|
        raw = tag.text.to_s.strip
        next if raw.empty?
        parsed = safe_parse(raw)
        next if parsed.nil?
        # JSON-LD <script> may contain a single object, an array of objects, or
        # an object with an @graph array. Use explicit branching here — do NOT
        # use Array(parsed), which would turn a Hash into [[k,v]...] entries.
        roots = parsed.is_a?(Array) ? parsed : [ parsed ]
        roots.each do |obj|
          flatten_graph(obj).each do |item|
            nodes << item if product?(item)
          end
        end
      end
      nodes
    end

    def safe_parse(raw)
      JSON.parse(raw)
    rescue JSON::ParserError
      nil
    end

    # Some sites wrap everything in {"@graph": [...]}.
    def flatten_graph(obj)
      return [] unless obj.is_a?(Hash)
      if obj["@graph"].is_a?(Array)
        obj["@graph"]
      else
        [ obj ]
      end
    end

    PRODUCT_TYPES = %w[Product ProductGroup IndividualProduct ProductModel].freeze

    def product?(item)
      return false unless item.is_a?(Hash)
      type = item["@type"]
      Array(type).any? { |t| PRODUCT_TYPES.include?(t.to_s) }
    end

    # Returns the first usable Offer hash. Tries (in order):
    #   1. node.offers as Hash               (Product with single Offer)
    #   2. node.offers as AggregateOffer     (unwrap AggregateOffer.offers[0])
    #   3. node.offers as Array              (take first)
    #   4. node.hasVariant[i].offers         (ProductGroup variant case)
    def first_offer(product)
      direct = direct_offer(product["offers"])
      return direct if direct

      variants = product["hasVariant"]
      return nil unless variants.is_a?(Array)
      variants.each do |variant|
        next unless variant.is_a?(Hash)
        offer = direct_offer(variant["offers"])
        return offer if offer && (offer["price"].to_s.length.positive? || offer["lowPrice"].to_s.length.positive?)
      end
      nil
    end

    def direct_offer(offers)
      case offers
      when Hash
        if offers["@type"].to_s == "AggregateOffer" && offers["offers"].is_a?(Array)
          offers["offers"].first
        else
          offers
        end
      when Array
        offers.first
      end
    end

    def first_image(image)
      case image
      when String then image
      when Array  then image.find { |i| i.is_a?(String) }
      when Hash   then image["url"] || image["contentUrl"]
      end
    end

    def stringify(value)
      value.is_a?(String) ? value.strip : nil
    end
  end
end
