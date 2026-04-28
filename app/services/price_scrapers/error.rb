module PriceScrapers
  # Base class so callers can rescue all scraper failures with one rescue.
  class Error < StandardError; end
end
