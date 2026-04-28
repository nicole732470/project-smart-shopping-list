require "json"

module PriceScrapers
  # Generic adapter that reads schema.org Product data from
  # <script type="application/ld+json"> blocks. Most modern retailers
  # publish this for SEO (rich snippets in Google), so this single class
  # covers a large fraction of e-commerce sites.
  #
  # Returns a Result with whatever fields it could extract; missing fields
  # are nil rather than raising. The PermanentError is reserved for the
  # case where no JSON-LD Product could be located at all.
  class JsonLdAdapter < Base
    def parse(doc, url)
      products = collect_product_nodes(doc)
      raise PermanentError, "No schema.org Product JSON-LD found" if products.empty?

      product = products.first
      offer   = first_offer(product)

      Result.new(
        price:     parse_price(offer&.dig("price") || offer&.dig("lowPrice")),
        currency: (offer&.dig("priceCurrency") || "USD"),
        title:     stringify(product["name"]),
        image_url: first_image(product["image"]),
        # store_name left blank; Base fills from host
      )
    end

    private

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
        [obj]
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
