module PriceScrapers
  # Site refused / shape unrecognized / 4xx that won't fix itself.
  # Don't retry until a human looks at it.
  class PermanentError < Error; end
end
