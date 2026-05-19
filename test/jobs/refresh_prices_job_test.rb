require "test_helper"

class RefreshPricesJobTest < ActiveJob::TestCase
  setup do
    @product = products(:one)
    @product.update_columns(source_url: "https://www.example.com/p/123", last_fetched_at: 2.days.ago)
  end

  test "perform calls refresh_batch with schedule-derived limit" do
    called_with = nil
    stub_method(PriceFetcher, :refresh_batch, ->(**kwargs) {
      called_with = kwargs
      { total: 1, batch_size: kwargs[:limit], succeeded: 1, failed: 0, duration: 0.1 }
    }) do
      RefreshPricesJob.perform_now
    end

    assert_equal RefreshSchedule.batch_size, called_with[:limit]
    assert_equal RefreshSchedule.stale_after, called_with[:min_age]
    assert_equal 0, called_with[:sleep_between]
  end

  test "perform skips when advisory lock is held" do
    RefreshPricesJob.new.send(:acquire_lock)
    called = false
    stub_method(PriceFetcher, :refresh_batch, ->(**_kwargs) { called = true }) do
      RefreshPricesJob.perform_now
    end
    refute called
  ensure
    RefreshPricesJob.new.send(:release_lock)
  end
end
