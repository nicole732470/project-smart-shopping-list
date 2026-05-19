require "test_helper"

class RefreshPricesJobTest < ActiveJob::TestCase
  setup do
    @product = products(:one)
    @product.update_columns(source_url: "https://www.amazon.com/dp/B000TEST01", last_fetched_at: 2.days.ago)
    @run = PriceRefreshRun.create!(
      triggered_by: "manual",
      status: "pending",
      batch_size: RefreshSchedule.batch_size,
      enqueued_at: Time.current
    )
  end

  test "perform calls refresh_batch with schedule-derived limit and records summary" do
    called_with = nil
    stub_method(PriceFetcher, :refresh_batch, ->(**kwargs) {
      called_with = kwargs
      {
        total: 1,
        catalog_with_url: 1,
        batch_size: kwargs[:limit],
        attempted: 1,
        succeeded: 1,
        failed: 0,
        stale_remaining: 0,
        failures: [],
        duration: 0.1,
        batches_run: 1
      }
    }) do
      RefreshPricesJob.perform_now(@run.id)
    end

    assert_equal RefreshSchedule.batch_size, called_with[:limit]
    assert_equal RefreshSchedule.stale_after, called_with[:min_age]
    assert_equal 0, called_with[:sleep_between]

    @run.reload
    assert_equal "completed", @run.status
    assert_equal 1, @run.succeeded
    assert_not_nil @run.finished_at
  end

  test "full_cycle runs batches until stale_remaining is zero" do
    calls = 0
    stub_method(PriceFetcher, :refresh_batch, ->(**kwargs) {
      calls += 1
      stale = calls == 1 ? 2 : 0
      {
        total: 5,
        catalog_with_url: 10,
        batch_size: kwargs[:limit],
        attempted: 1,
        succeeded: 1,
        failed: 0,
        stale_remaining: stale,
        failures: [],
        duration: 0.1
      }
    }) do
      RefreshPricesJob.perform_now(@run.id, full_cycle: true)
    end

    assert_equal 2, calls
    @run.reload
    assert_equal 2, @run.batches_run
    assert_equal 2, @run.attempted
    assert_equal 0, @run.stale_remaining
  end

  test "perform skips when advisory lock is not acquired" do
    called = false
    job = RefreshPricesJob.new
    job.define_singleton_method(:acquire_lock) { false }

    stub_method(PriceFetcher, :refresh_batch, ->(**_kwargs) { called = true }) do
      job.perform(@run.id)
    end

    refute called
    @run.reload
    assert_equal "skipped_overlap", @run.status
    assert_not_nil @run.finished_at
  end
end
