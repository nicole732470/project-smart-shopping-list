class RefreshPricesJob < ApplicationJob
  queue_as :default

  # PostgreSQL advisory lock — prevents overlapping batches when a scrape
  # run outlasts the cron interval. No Redis required.
  ADVISORY_LOCK_KEY = 0x5052_4943_45 # "PRICE"

  FAILURE_DETAIL_LIMIT = 100

  def perform(refresh_run_id, full_cycle: false)
    run = PriceRefreshRun.find(refresh_run_id)
    run.update!(status: "running", started_at: Time.current)

    unless acquire_lock
      run.update!(
        status: "skipped_overlap",
        total_products: Product.refreshable.count,
        batch_size: RefreshSchedule.batch_size,
        finished_at: Time.current
      )
      Rails.logger.warn("[RefreshPricesJob] skipped_due_to_overlap — previous batch still running")
      return
    end

    begin
      run.apply_summary!(run_cycle(full_cycle: full_cycle))
    rescue StandardError => e
      run.update!(
        status: "failed",
        error_message: e.message.to_s.first(500),
        finished_at: Time.current
      )
      raise
    ensure
      release_lock
    end
  end

  private

  def run_cycle(full_cycle:)
    started_at = Time.current
    limit = RefreshSchedule.batch_size
    min_age = RefreshSchedule.stale_after

    attempted = succeeded = failed = 0
    failures = []
    batches_run = 0
    last_batch_size = limit
    total = Product.refreshable.count
    catalog_with_url = Product.with_trackable_url.count
    stale_remaining = total

    loop do
      summary = PriceFetcher.refresh_batch(limit: limit, min_age: min_age, sleep_between: 0)
      batches_run += 1
      last_batch_size = summary[:batch_size]
      attempted += summary[:attempted]
      succeeded += summary[:succeeded]
      failed += summary[:failed]
      failures.concat(summary[:failures])
      stale_remaining = summary[:stale_remaining]

      break unless full_cycle
      break if summary[:attempted].zero?
      break if stale_remaining.zero?
    end

    {
      total: total,
      catalog_with_url: catalog_with_url,
      batch_size: last_batch_size,
      batches_run: batches_run,
      attempted: attempted,
      succeeded: succeeded,
      failed: failed,
      stale_remaining: stale_remaining,
      failures: failures.first(FAILURE_DETAIL_LIMIT),
      duration: (Time.current - started_at).round(1)
    }.tap do |aggregate|
      Rails.logger.info("[RefreshPricesJob] full_cycle=#{full_cycle} #{aggregate.inspect}")
    end
  end

  def acquire_lock
    ActiveRecord::Base.connection.select_value(
      "SELECT pg_try_advisory_lock(#{ADVISORY_LOCK_KEY})"
    )
  end

  def release_lock
    ActiveRecord::Base.connection.select_value(
      "SELECT pg_advisory_unlock(#{ADVISORY_LOCK_KEY})"
    )
  end
end
