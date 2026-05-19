require "test_helper"

class PriceRefreshRunTest < ActiveSupport::TestCase
  test "apply_summary! marks run completed with counts" do
    run = PriceRefreshRun.create!(
      triggered_by: "manual",
      status: "running",
      enqueued_at: 1.minute.ago,
      started_at: 30.seconds.ago
    )

    run.apply_summary!(
      total: 100,
      catalog_with_url: 1200,
      batch_size: 5,
      attempted: 5,
      succeeded: 4,
      failed: 1,
      stale_remaining: 80,
      failures: [ { "product_id" => 1, "name" => "X", "error" => "timeout" } ],
      failure_summary: { "total_failures" => 1, "by_category" => [] },
      duration: 12.3
    )

    run.reload
    assert_equal "completed", run.status
    assert_equal 4, run.succeeded
    assert_equal 1, run.failed
    assert_equal({ "total_failures" => 1, "by_category" => [] }, run.failure_summary)
    assert_equal 80, run.stale_remaining
    assert_not_nil run.finished_at
  end

  test "terminal? is true for finished statuses" do
    run = PriceRefreshRun.new(status: "completed")
    assert run.terminal?

    run.status = "running"
    refute run.terminal?
  end
end
