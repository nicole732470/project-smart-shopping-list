module PriceScrapers
  # Maps a URL host to the right adapter. The default fallback is JsonLdAdapter,
  # which works for most schema.org-compliant retailers (Best Buy, Target,
  # Newegg, Apple, B&H, Walmart, Lululemon, Nike, etc.).
  #
  # To add a site-specific adapter, add a regex -> class entry to ADAPTERS.
  # See docs/scrapers.md for the full guide.
  class Registry
    ADAPTERS = [
      [ /(\A|\.)amazon\.[a-z.]+\z/, AmazonAdapter ],
    ].freeze

    def self.for(url)
      host = URI.parse(url.to_s).host.to_s.downcase
      ADAPTERS.each do |pattern, klass|
        return klass.new if host.match?(pattern)
      end
      JsonLdAdapter.new
    end
  end
end
