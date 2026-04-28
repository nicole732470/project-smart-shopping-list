module PriceScrapers
  # Top-level facade. Looks up the right adapter by URL host and delegates.
  #
  #   result = PriceScrapers.fetch("https://www.target.com/p/.../A-12345678", timeout: 5)
  #   result.price        # => BigDecimal("249.99") or nil
  #   result.title        # => "Apple AirPods Pro (2nd Gen)" or nil
  #   result.image_url    # => "https://target.scene7.com/..." or nil
  #   result.store_name   # => "Target"
  #   result.fetched_at   # => Time
  #
  # Raises PriceScrapers::Error subclasses on hard failures (HTTP error, parse
  # failure, etc). Callers should rescue PriceScrapers::Error.
  def self.fetch(url, timeout: 5)
    adapter = Registry.for(url)
    adapter.fetch(url, timeout: timeout)
  end
end
