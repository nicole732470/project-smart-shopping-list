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
    product.update_columns(last_fetch_error: e.message.to_s.first(250))
    product
  end

  # Refresh every product that has a source_url. Use this when products are
  # few and you want each scheduler run to truly re-check them all.
  #
  # Called by Heroku Scheduler:
  #   bin/rails runner "PriceFetcher.refresh_all"
  def self.refresh_all
    Product.where.not(source_url: nil).find_each do |product|
      call(product)
      sleep 1
    end
  end

  # Refresh only products not fetched within `min_age`. Use this when the
  # scheduler runs more frequently than you want each product re-checked,
  # or when there are many products.
  #
  #   bin/rails runner "PriceFetcher.refresh_stale"
  def self.refresh_stale(min_age: 2.days)
    Product.where.not(source_url: nil)
           .where("last_fetched_at IS NULL OR last_fetched_at < ?", min_age.ago)
           .find_each do |product|
      call(product)
      sleep 1
    end
  end
end
