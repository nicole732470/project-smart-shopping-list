require "test_helper"

class ProductTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @product = @user.products.build(name: "Test Product", category: "Electronics")
  end

  test "valid product" do
    assert @product.valid?
  end

  test "invalid without name" do
    @product.name = ""
    assert_not @product.valid?
  end

  test "invalid without category" do
    @product.category = ""
    assert_not @product.valid?
  end

  test "lowest_price returns nil when no records" do
    @product.save!
    assert_nil @product.lowest_price
  end

  test "latest_price returns most recent price" do
    @product.save!
    @product.price_records.create!(price: 100, store_name: "Amazon", recorded_at: 2.days.ago)
    @product.price_records.create!(price: 90, store_name: "Walmart", recorded_at: 1.day.ago)
    assert_equal 90, @product.latest_price
  end

  test "lowest_price returns minimum price" do
    @product.save!
    @product.price_records.create!(price: 120, store_name: "Amazon", recorded_at: 3.days.ago)
    @product.price_records.create!(price: 90, store_name: "Walmart", recorded_at: 2.days.ago)
    @product.price_records.create!(price: 105, store_name: "Target", recorded_at: 1.day.ago)
    assert_equal 90, @product.lowest_price
  end

  # --- Price Trend Tests ---

  test "price_trend returns nil with less than 2 records" do
    @product.save!
    assert_nil @product.price_trend
  end

  test "price_trend returns :up when price increases significantly" do
    @product.save!
    @product.price_records.create!(price: 100, store_name: "Amazon", recorded_at: 5.days.ago)
    @product.price_records.create!(price: 95, store_name: "Amazon", recorded_at: 4.days.ago)
    @product.price_records.create!(price: 98, store_name: "Amazon", recorded_at: 3.days.ago)
    @product.price_records.create!(price: 110, store_name: "Amazon", recorded_at: 1.day.ago)

    assert_equal :up, @product.price_trend
  end

  test "price_trend returns :down when price decreases significantly" do
    @product.save!
    @product.price_records.create!(price: 100, store_name: "Amazon", recorded_at: 5.days.ago)
    @product.price_records.create!(price: 105, store_name: "Amazon", recorded_at: 4.days.ago)
    @product.price_records.create!(price: 102, store_name: "Amazon", recorded_at: 3.days.ago)
    @product.price_records.create!(price: 85, store_name: "Amazon", recorded_at: 1.day.ago)

    assert_equal :down, @product.price_trend
  end

  test "price_trend returns :stable when price changes are within threshold" do
    @product.save!
    @product.price_records.create!(price: 100, store_name: "Amazon", recorded_at: 3.days.ago)
    @product.price_records.create!(price: 101, store_name: "Amazon", recorded_at: 2.days.ago)
    @product.price_records.create!(price: 102, store_name: "Amazon", recorded_at: 1.day.ago)

    assert_equal :stable, @product.price_trend
  end

  test "price_trend_emoji returns correct emoji for trend" do
    @product.save!
    @product.price_records.create!(price: 100, store_name: "Amazon", recorded_at: 2.days.ago)
    @product.price_records.create!(price: 110, store_name: "Amazon", recorded_at: 1.day.ago)

    assert_equal "📈", @product.price_trend_emoji
  end

  test "price_trend_description returns human-readable trend" do
    @product.save!
    @product.price_records.create!(price: 100, store_name: "Amazon", recorded_at: 2.days.ago)
    @product.price_records.create!(price: 110, store_name: "Amazon", recorded_at: 1.day.ago)

    assert_match(/trending up/i, @product.price_trend_description)
  end

  # --- Target Price Tests ---

  test "valid when target_price is nil (alerts are opt-in)" do
    @product.target_price = nil
    assert @product.valid?
  end

  test "valid when target_price is a positive number" do
    @product.target_price = 99.99
    assert @product.valid?
  end

  test "invalid when target_price is zero or negative" do
    @product.target_price = 0
    assert_not @product.valid?
    assert_includes @product.errors[:target_price].first, "greater than"

    @product.target_price = -5
    assert_not @product.valid?
  end

  test "invalid when target_price exceeds the column precision cap" do
    @product.target_price = 99_999_999.99
    assert_not @product.valid?
  end

  test "alert_cooldown_active? is false when last_alerted_at is nil" do
    @product.last_alerted_at = nil
    refute @product.alert_cooldown_active?
  end

  test "alert_cooldown_active? is true within the 24h window" do
    @product.last_alerted_at = 1.hour.ago
    assert @product.alert_cooldown_active?
  end

  test "alert_cooldown_active? is false after the 24h window" do
    @product.last_alerted_at = 25.hours.ago
    refute @product.alert_cooldown_active?
  end

  test "target_price_alert_enabled? mirrors presence of target_price" do
    @product.target_price = nil
    refute @product.target_price_alert_enabled?

    @product.target_price = 1
    assert @product.target_price_alert_enabled?
  end

  # --- recent_alert? / alert_trigger_record helpers ---

  test "recent_alert? is false when last_alerted_at is nil" do
    @product.last_alerted_at = nil
    refute @product.recent_alert?
  end

  test "recent_alert? is true within the 7-day window" do
    @product.last_alerted_at = 2.days.ago
    assert @product.recent_alert?
  end

  test "recent_alert? is false after the 7-day window" do
    @product.last_alerted_at = 8.days.ago
    refute @product.recent_alert?
  end

  test "recent_alert? honors a custom window override" do
    @product.last_alerted_at = 3.hours.ago
    assert @product.recent_alert?(window: 1.day)
    refute @product.recent_alert?(window: 1.hour)
  end

  test "alert_trigger_record returns nil when no alert has fired" do
    @product.save!
    @product.last_alerted_at = nil
    assert_nil @product.alert_trigger_record
  end

  test "alert_trigger_record returns the latest record at or before last_alerted_at" do
    # We're explicitly testing the lookup query, not the alerter pipeline.
    # Without this, the third create! would fire PriceAlerter, which would
    # overwrite last_alerted_at with Time.current and pull a newer record
    # into the trigger window.
    PriceRecord.alerter_callback_enabled = false
    @product.save!
    older  = @product.price_records.create!(price: 120, store_name: "A", recorded_at: 5.days.ago)
    target = @product.price_records.create!(price:  80, store_name: "B", recorded_at: 2.days.ago)
    @product.update_columns(last_alerted_at: 2.days.ago + 1.minute)
    @product.price_records.create!(price: 75, store_name: "C", recorded_at: 1.day.ago)

    assert_equal target.id, @product.alert_trigger_record.id
    refute_equal older.id, @product.alert_trigger_record.id
  ensure
    PriceRecord.alerter_callback_enabled = true
  end

  test "scrapeable excludes example.com and search URLs" do
    @product.source_url = "https://www.amazon.com/dp/B123"
    assert @product.scrapeable?

    @product.source_url = "https://example.com/p/1"
    refute @product.scrapeable?

    @product.source_url = "https://www.amazon.com/search?q=phone"
    refute @product.scrapeable?
  end

  test "refreshable is scrapeable with auto_refresh enabled" do
    user = User.create!(
      email_address: Product::PAGINATION_TEST_EMAIL,
      password: "Pagy123!",
      password_confirmation: "Pagy123!"
    )
    user.products.create!(
      name: "Load test",
      category: "Books",
      source_url: "https://www.amazon.com/dp/B091G65HH6"
    )
    manual = user.products.create!(
      name: "Manual only",
      category: "Books",
      source_url: "https://www.amazon.com/dp/B091G65HH6",
      auto_refresh: false
    )

    assert_equal 1, Product.refreshable.where(user_id: user.id).count
    refute_includes Product.refreshable, manual
    assert_equal Product.scrapeable.where(auto_refresh: true).count, Product.refreshable.count
  end

  test "show_refresh_failure? is false when auto_refresh is off" do
    @product.save!
    @product.update_columns(
      auto_refresh: false,
      last_fetch_error: "HTTP 503"
    )
    refute @product.reload.show_refresh_failure?
  end

  test "show_refresh_failure? is true when auto_refresh is on and error present" do
    @product.save!
    @product.update_columns(
      auto_refresh: true,
      last_fetch_error: "HTTP 503"
    )
    assert @product.reload.show_refresh_failure?
  end

  test "clearing auto_refresh clears last_fetch_error on save" do
    @product.save!
    @product.update_columns(
      source_url: "https://www.amazon.com/dp/B123",
      auto_refresh: true,
      last_fetch_error: "timeout"
    )
    @product.update!(auto_refresh: false)
    assert_nil @product.last_fetch_error
  end
end
