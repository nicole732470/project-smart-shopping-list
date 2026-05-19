require "test_helper"

class PriceFetcherTest < ActiveSupport::TestCase
  SCRAPEABLE_URL = "https://www.amazon.com/dp/B000TEST01".freeze
  SCRAPEABLE_BAD_URL = "https://www.amazon.com/dp/B000BAD001".freeze

  setup do
    @product = products(:one)
    @product.update_columns(source_url: SCRAPEABLE_URL)
  end

  def stub_fetch(price:, title: "Stubbed Title", image_url: "https://img/x.jpg", store: "Example", &block)
    result = PriceScrapers::Result.new(
      price:      price,
      currency:   "USD",
      title:      title,
      image_url:  image_url,
      store_name: store,
      fetched_at: Time.current
    )
    stub_method(PriceScrapers, :fetch, ->(_url, **_opts) { result }, &block)
  end

  test ".call creates a scraped PriceRecord and updates last_fetched_at" do
    initial_count = @product.price_records.count

    stub_fetch(price: BigDecimal("99.99")) do
      PriceFetcher.call(@product)
    end

    @product.reload
    assert_equal initial_count + 1, @product.price_records.count
    record = @product.price_records.order(recorded_at: :desc).first
    assert_equal "scraped", record.source
    assert_equal BigDecimal("99.99"), record.price
    assert_not_nil @product.last_fetched_at
    assert_nil @product.last_fetch_error
  end

  test ".call de-dupes identical prices (no new row when nothing changed)" do
    stub_fetch(price: BigDecimal("50.00")) do
      PriceFetcher.call(@product)
    end
    count_after_first = @product.reload.price_records.count

    stub_fetch(price: BigDecimal("50.00")) do
      PriceFetcher.call(@product)
    end

    assert_equal count_after_first, @product.reload.price_records.count,
                 "should not create a new price record when price hasn't changed"
    assert_not_nil @product.last_fetched_at
  end

  test ".call writes a new row when price changes" do
    stub_fetch(price: BigDecimal("50.00")) do
      PriceFetcher.call(@product)
    end
    stub_fetch(price: BigDecimal("45.00")) do
      PriceFetcher.call(@product)
    end

    scraped = @product.reload.price_records.where(source: "scraped").order(recorded_at: :asc)
    assert_equal 2, scraped.count
    assert_equal BigDecimal("50.00"), scraped.first.price
    assert_equal BigDecimal("45.00"), scraped.last.price
  end

  test ".call NEVER mutates name / image_url / description / category" do
    original_name = @product.name
    original_image = @product.image_url
    original_category = @product.category
    original_description = @product.description

    stub_fetch(price: BigDecimal("25.00"), title: "Different Title", image_url: "https://different/img.jpg") do
      PriceFetcher.call(@product)
    end

    @product.reload
    assert_equal original_name, @product.name
    assert_equal original_image, @product.image_url
    assert_equal original_category, @product.category
    assert_equal original_description, @product.description
  end

  test ".call records last_fetch_error on PriceScrapers::Error and does not crash" do
    stub_method(PriceScrapers, :fetch, ->(*_args, **_kw) { raise PriceScrapers::TransientError, "network blip" }) do
      assert_nothing_raised { PriceFetcher.call(@product) }
    end
    @product.reload
    assert_match(/network blip/, @product.last_fetch_error)
    assert_not_nil @product.last_fetched_at
  end

  test ".call no-ops on a product without source_url (manual-only products are safe)" do
    manual_product = products(:two)
    assert_nil manual_product.source_url

    stub_method(PriceScrapers, :fetch, ->(*) { raise "scrape should not have been attempted" }) do
      assert_nothing_raised { PriceFetcher.call(manual_product) }
    end
    assert_equal 0, manual_product.reload.price_records.where(source: "scraped").count
  end

  test ".refresh_stale only touches products that haven't been fetched in min_age" do
    fresh = Product.create!(
      user: users(:one), name: "Fresh", category: "Electronics",
      source_url: "https://example.com/fresh", last_fetched_at: Time.current
    )

    fetched = []
    stub_method(PriceScrapers, :fetch, ->(url, **_opts) {
      fetched << url
      PriceScrapers::Result.new(
        price: BigDecimal("1.00"), title: "X", image_url: nil,
        store_name: "X", fetched_at: Time.current
      )
    }) do
      PriceFetcher.refresh_stale(min_age: 1.day)
    end

    assert_includes fetched, @product.source_url
    refute_includes fetched, fresh.source_url
  end

  # ---------- refresh_all (the daily cron entry point) ----------

  test ".refresh_all returns a summary hash with succeeded / failed / duration" do
    stub_method(PriceScrapers, :fetch, ->(_url, **_opts) {
      PriceScrapers::Result.new(
        price: BigDecimal("10.00"), title: "X", image_url: nil,
        store_name: "X", fetched_at: Time.current
      )
    }) do
      summary = PriceFetcher.refresh_all
      assert_kind_of Hash, summary
      assert_includes summary.keys, :succeeded
      assert_includes summary.keys, :failed
      assert_includes summary.keys, :duration
    end
  end

  test ".refresh_all counts a scrape that raised PriceScrapers::Error as failed, not succeeded" do
    # Fixture has @product (source_url set in setup) and one other product
    # without a source_url, plus we add a second eligible product here so
    # we can prove the counter splits succeeded vs failed correctly.
    bad = Product.create!(
      user: users(:one), name: "Bad", category: "Electronics",
      source_url: "https://example.com/bad"
    )

    stub_method(PriceScrapers, :fetch, ->(url, **_opts) {
      raise PriceScrapers::TransientError, "boom" if url.include?("/bad")
      PriceScrapers::Result.new(
        price: BigDecimal("10.00"), title: "X", image_url: nil,
        store_name: "X", fetched_at: Time.current
      )
    }) do
      summary = PriceFetcher.refresh_all
      assert_equal 1, summary[:succeeded], "the @product fetch should be counted as succeeded"
      assert_equal 1, summary[:failed],    "the bad-url product should be counted as failed"
    end

    assert_match(/boom/, bad.reload.last_fetch_error)
    assert_nil @product.reload.last_fetch_error
  end

  test ".refresh_all skips products with no source_url entirely" do
    fetched = []
    stub_method(PriceScrapers, :fetch, ->(url, **_opts) {
      fetched << url
      PriceScrapers::Result.new(
        price: BigDecimal("1.00"), title: "X", image_url: nil,
        store_name: "X", fetched_at: Time.current
      )
    }) do
      PriceFetcher.refresh_all
    end

    # products(:two) has no source_url and must not appear in the fetched list.
    refute_includes fetched, products(:two).source_url
    refute fetched.any?(&:nil?)
  end

  test ".refresh_all does not raise when an individual product fails" do
    # Whole-cron robustness: even if every product fails, refresh_all still
    # returns a summary instead of bubbling the exception up to the caller
    # (which in production is AdminController and ultimately the GitHub
    # Actions runner — we don't want a single bad URL to red-X the whole job).
    stub_method(PriceScrapers, :fetch, ->(*_a, **_kw) {
      raise PriceScrapers::PermanentError, "every product is bad"
    }) do
      assert_nothing_raised do
        summary = PriceFetcher.refresh_all
        assert_operator summary[:failed], :>=, 1
      end
    end
  end

  # ---------- refresh_batch (cron job entry point) ----------

  test ".refresh_batch refreshes up to limit stale products oldest-first" do
    stale = Product.create!(
      user: users(:one), name: "Stale", category: "Electronics",
      source_url: "https://www.amazon.com/dp/B000STALE1", last_fetched_at: 3.days.ago
    )
    fresh = Product.create!(
      user: users(:one), name: "Fresh", category: "Electronics",
      source_url: "https://www.amazon.com/dp/B000FRESH1", last_fetched_at: 1.hour.ago
    )

    fetched = []
    stub_method(PriceScrapers, :fetch, ->(url, **_opts) {
      fetched << url
      PriceScrapers::Result.new(
        price: BigDecimal("10.00"), title: "X", image_url: nil,
        store_name: "X", fetched_at: Time.current
      )
    }) do
      summary = PriceFetcher.refresh_batch(limit: 10, min_age: 1.day, sleep_between: 0)
      assert_includes summary.keys, :total
      assert_includes summary.keys, :batch_size
      assert_includes summary.keys, :runs_per_cycle
    end

    assert_includes fetched, stale.source_url
    refute_includes fetched, fresh.source_url
  end

  test ".refresh_batch returns summary with succeeded and failed counts" do
    stub_method(PriceScrapers, :fetch, ->(_url, **_opts) {
      PriceScrapers::Result.new(
        price: BigDecimal("10.00"), title: "X", image_url: nil,
        store_name: "X", fetched_at: Time.current
      )
    }) do
      summary = PriceFetcher.refresh_batch(limit: 5, min_age: 1.day, sleep_between: 0)
      assert_kind_of Integer, summary[:attempted]
      assert_kind_of Integer, summary[:succeeded]
      assert_kind_of Integer, summary[:failed]
      assert_kind_of Integer, summary[:stale_remaining]
      assert_kind_of Array, summary[:failures]
      assert_kind_of Float, summary[:duration]
    end
  end

  test ".refresh_batch records failure details when scrape errors" do
    @product.update_columns(source_url: SCRAPEABLE_BAD_URL, last_fetched_at: 2.days.ago)

    stub_method(PriceScrapers, :fetch, ->(*_args, **_kw) {
      raise PriceScrapers::TransientError, "network blip"
    }) do
      summary = PriceFetcher.refresh_batch(limit: 5, min_age: 1.day, sleep_between: 0)
      assert_equal 1, summary[:failed]
      assert_equal 1, summary[:failures].size
      assert_equal @product.id, summary[:failures].first["product_id"]
      assert_match(/network blip/, summary[:failures].first["error"])
      assert_equal @product.source_url, summary[:failures].first["source_url"]
      assert_equal "www.amazon.com", summary[:failures].first["host"]
    end
  end
end
