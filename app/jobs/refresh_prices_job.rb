class RefreshPricesJob < ApplicationJob
  queue_as :default

  # PostgreSQL advisory lock — prevents overlapping batches when a scrape
  # run outlasts the cron interval. No Redis required.
  ADVISORY_LOCK_KEY = 0x5052_4943_45 # "PRICE"

  def perform
    unless acquire_lock
      Rails.logger.warn("[RefreshPricesJob] skipped_due_to_overlap — previous batch still running")
      return
    end

    begin
      limit = RefreshSchedule.batch_size
      summary = PriceFetcher.refresh_batch(
        limit: limit,
        min_age: RefreshSchedule.stale_after,
        sleep_between: 0
      )
      Rails.logger.info("[RefreshPricesJob] #{summary.inspect}")
    ensure
      release_lock
    end
  end

  private

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
