# Aggregates per-product scrape failures into a readable summary for
# PriceRefreshRun and GitHub Actions. Full runs can fail hundreds of times;
# storing every row is noisy — we keep counts by category/host/error plus a
# small set of representative samples (with URL + account).
class RefreshFailureReport
  MAX_SAMPLES = 50

  def initialize
    @by_error = Hash.new(0)
    @by_host = Hash.new(0)
    @by_category = Hash.new(0)
    @samples = {}
  end

  def record(failure)
    error = failure["error"].to_s
    host = failure["host"].presence || host_from_url(failure["source_url"])
    category = categorize(error)

    @by_error[error] += 1
    @by_host[host] += 1
    @by_category[category] += 1

    sample_key = "#{category}|#{host}"
    return if @samples.size >= MAX_SAMPLES && !@samples.key?(sample_key)

    @samples[sample_key] = failure.merge(
      "category" => category,
      "host" => host
    )
  end

  def record_all(failures)
    Array(failures).each { |failure| record(failure) }
    self
  end

  def to_h
    total = @by_error.values.sum
    {
      "total_failures" => total,
      "by_category" => top_counts(@by_category, 15),
      "by_host" => top_counts(@by_host, 15),
      "by_error" => top_counts(@by_error, 20),
      "samples" => @samples.values
    }
  end

  private

  def top_counts(hash, limit)
    hash.sort_by { |_, count| -count }
        .first(limit)
        .map { |label, count| { "label" => label, "count" => count } }
  end

  def host_from_url(url)
    URI.parse(url.to_s).host.presence || "unknown"
  rescue URI::InvalidURIError
    "unknown"
  end

  def categorize(error)
    case error
    when /\AHTTP 403/ then "HTTP 403 — blocked (bot/WAF)"
    when /\AHTTP 404/ then "HTTP 404 — page not found"
    when /\AHTTP 429/ then "HTTP 429 — rate limited"
    when /\AHTTP 5\d{2}/ then "HTTP 5xx — server error"
    when /timeout/i, /Timed out/i, /execution expired/i then "Timeout"
    when /JSON-LD/i then "No product JSON-LD"
    when /connection refused/i, /failed to open/i, /SSL/i then "Network / TLS"
    else error.truncate(100)
    end
  end
end
