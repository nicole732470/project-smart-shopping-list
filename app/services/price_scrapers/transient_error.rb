module PriceScrapers
  # Network-level problem: timeout, DNS failure, refused connection, 5xx.
  # Generally retryable next time the scheduler runs.
  class TransientError < Error; end
end
