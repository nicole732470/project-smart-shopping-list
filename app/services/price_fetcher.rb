class PriceFetcher
  # Fetch the latest price for a single product.
  #
  # Behaviour:
  #   - Skips products with no source_url (manual-only products are untouched).
  #   - Catches all PriceScrapers::Error so callers (controllers / scheduler)
  #     never crash. Failures are surfaced via product.last_fetch_error.
  #   - DEDUP: only writes a new PriceRecord(source: "scraped") when the price
  #     actually differs from the last scraped record. This means even an
  #     hourly cron won't pollute price history with thousands of identical
  #     rows; the chart shows only real price changes.
  #   - NEVER mutates name / image_url / description / category. Those are
  #     populated only at product creation time (in ProductsController#create).
  #
  # Returns the product (always), so callers can chain or inspect.
  def self.call(product)
    return product if product.source_url.blank?

    result = PriceScrapers.fetch(product.source_url, timeout: 5)

    if result.price.present?
      last_scraped = product.price_records
                            .where(source: "scraped")
                            .order(recorded_at: :desc)
                            .first
      if last_scraped.nil? || last_scraped.price != result.price
        product.price_records.create!(
          price:       result.price,
          store_name:  result.store_name,
          url:         product.source_url,
          recorded_at: result.fetched_at,
          source:      "scraped"
        )
      end
    end

    product.update_columns(
      last_fetched_at:  Time.current,
      last_fetch_error: nil
    )
    product
  rescue PriceScrapers::Error => e
    product.update_columns(
      last_fetch_error: e.message.to_s.first(250),
      last_fetched_at: Time.current
    )
    product
  end

  # Refresh up to `limit` stale products, oldest-first. Used by RefreshPricesJob
  # on each cron tick. Batch size is computed by RefreshSchedule from the
  # current product count so the catalog is covered within the refresh window
  # without redeploying when load grows.
  def self.refresh_batch(limit:, min_age: 23.hours, sleep_between: 0)
    started_at = Time.current
    total = Product.refreshable.count
    catalog_with_url = Product.with_trackable_url.count

    scope = Product.refreshable
                   .where("last_fetched_at IS NULL OR last_fetched_at < ?", min_age.ago)
                   .order(Arel.sql("last_fetched_at ASC NULLS FIRST"))
                   .limit(limit)

    succeeded = failed = 0
    failures = []
    scope.includes(:user).find_each do |product|
      call(product)
      if product.last_fetch_error.present?
        failed += 1
        failures << failure_detail_for(product)
      else
        succeeded += 1
      end
      sleep sleep_between if sleep_between.positive?
    end

    stale_remaining = Product.refreshable
                             .where("last_fetched_at IS NULL OR last_fetched_at < ?", min_age.ago)
                             .count

    duration = (Time.current - started_at).round(1)
    summary = {
      total: total,
      catalog_with_url: catalog_with_url,
      batch_size: limit,
      runs_per_cycle: RefreshSchedule.runs_per_cycle,
      attempted: succeeded + failed,
      succeeded: succeeded,
      failed: failed,
      stale_remaining: stale_remaining,
      failures: failures,
      duration: duration
    }
    Rails.logger.info("[PriceFetcher] refresh_batch finished — #{summary.inspect}")
    summary
  end

  # Refresh every product that has a source_url. CLI / emergency use only —
  # the cron path enqueues RefreshPricesJob instead (async + batched).
  #
  #   bin/rails runner "PriceFetcher.refresh_all"
  def self.refresh_all
    started_at = Time.current
    Rails.logger.info("[PriceFetcher] refresh_all started at #{started_at.iso8601}")

    succeeded = failed = 0
    Product.where.not(source_url: nil).find_each do |product|
      call(product)
      product.last_fetch_error.present? ? failed += 1 : succeeded += 1
      sleep 1
    end

    duration = (Time.current - started_at).round(1)
    Rails.logger.info(
      "[PriceFetcher] refresh_all finished in #{duration}s — " \
      "succeeded=#{succeeded} failed=#{failed} total=#{succeeded + failed}"
    )
    { succeeded: succeeded, failed: failed, duration: duration }
  end

  # Refresh only products not fetched within `min_age`. Use this when the
  # scheduler runs more frequently than you want each product re-checked,
  # or when there are many products.
  #
  #   bin/rails runner "PriceFetcher.refresh_stale"
  def self.refresh_stale(min_age: 2.days)
    started_at = Time.current
    Rails.logger.info("[PriceFetcher] refresh_stale(min_age=#{min_age.inspect}) started at #{started_at.iso8601}")

    succeeded = failed = 0
    Product.where.not(source_url: nil)
           .where("last_fetched_at IS NULL OR last_fetched_at < ?", min_age.ago)
           .find_each do |product|
      call(product)
      product.last_fetch_error.present? ? failed += 1 : succeeded += 1
      sleep 1
    end

    duration = (Time.current - started_at).round(1)
    Rails.logger.info(
      "[PriceFetcher] refresh_stale finished in #{duration}s — " \
      "succeeded=#{succeeded} failed=#{failed} total=#{succeeded + failed}"
    )
    { succeeded: succeeded, failed: failed, duration: duration }
  end

  def self.failure_detail_for(product)
    {
      "product_id" => product.id,
      "name" => product.name.to_s.truncate(80),
      "source_url" => product.source_url,
      "host" => host_from_source_url(product.source_url),
      "user_email" => product.user.email_address,
      "error" => product.last_fetch_error
    }
  end

  def self.host_from_source_url(url)
    URI.parse(url.to_s).host.presence || "unknown"
  rescue URI::InvalidURIError
    "unknown"
  end

  private_class_method :failure_detail_for, :host_from_source_url
end
