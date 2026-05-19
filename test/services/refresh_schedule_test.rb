require "test_helper"

class RefreshScheduleTest < ActiveSupport::TestCase
  setup do
    @original_env = {
      "REFRESH_WINDOW_HOURS" => ENV["REFRESH_WINDOW_HOURS"],
      "REFRESH_INTERVAL_MINUTES" => ENV["REFRESH_INTERVAL_MINUTES"],
      "REFRESH_BATCH_MAX" => ENV["REFRESH_BATCH_MAX"]
    }
    ENV["REFRESH_WINDOW_HOURS"] = "2"
    ENV["REFRESH_INTERVAL_MINUTES"] = "5"
    ENV.delete("REFRESH_BATCH_MAX")
  end

  teardown do
    @original_env.each { |key, val| val.nil? ? ENV.delete(key) : ENV[key] = val }
  end

  test "runs_per_cycle is window divided by interval" do
    assert_equal 24, RefreshSchedule.runs_per_cycle
  end

  test "batch_size scales with product count" do
    user = users(:one)
    47.times do |i|
      user.products.create!(name: "P#{i}", category: "Electronics", source_url: "https://example.com/p/#{i}")
    end
    # fixtures: products(:one) has source_url from price_fetcher setup elsewhere;
    # count all with source_url
    total = Product.where.not(source_url: nil).count
    expected = (total.to_f / 24).ceil
    assert_equal expected, RefreshSchedule.batch_size
  end

  test "batch_size increases when product count grows" do
    user = users(:one)
    before = Product.where.not(source_url: nil).count
    size_before = RefreshSchedule.batch_size

    user.products.create!(name: "Grow", category: "Books", source_url: "https://example.com/grow")

    size_after = RefreshSchedule.batch_size
    expected = ((before + 1).to_f / RefreshSchedule.runs_per_cycle).ceil.clamp(1, RefreshSchedule.max_batch)
    assert_equal expected, size_after
    assert_operator size_after, :>=, size_before
  end

  test "batch_size respects REFRESH_BATCH_MAX cap" do
    ENV["REFRESH_BATCH_MAX"] = "3"
    user = users(:one)
    20.times do |i|
      user.products.create!(name: "Cap#{i}", category: "Books", source_url: "https://example.com/c/#{i}")
    end
    assert_equal 3, RefreshSchedule.batch_size
  end
end
