require "test_helper"

class PriceFetcherTest < ActiveSupport::TestCase
  setup do
    @product = products(:one)
    @product.update_columns(source_url: "https://www.example.com/p/123")
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
    assert_match(/network blip/, @product.reload.last_fetch_error)
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
end
