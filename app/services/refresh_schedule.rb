class RefreshSchedule
  # Computes how many products each cron-triggered batch should refresh so
  # the full catalog is covered within REFRESH_WINDOW_HOURS without hard-
  # coding batch sizes. When product count doubles, batch_size doubles
  # automatically — no code deploy required.
  #
  # Tuning via ENV (Heroku config vars):
  #   REFRESH_WINDOW_HOURS      — full-cycle target (default 2)
  #   REFRESH_INTERVAL_MINUTES  — cron cadence inside the window (default 5)
  #   REFRESH_STALE_HOURS       — skip products fetched more recently (default 23)
  #   REFRESH_BATCH_MAX         — safety cap per batch (default 500)

  def self.window_hours
    ENV.fetch("REFRESH_WINDOW_HOURS", 2).to_f
  end

  def self.interval_minutes
    ENV.fetch("REFRESH_INTERVAL_MINUTES", 5).to_i
  end

  def self.max_batch
    ENV.fetch("REFRESH_BATCH_MAX", 500).to_i
  end

  def self.stale_hours
    ENV.fetch("REFRESH_STALE_HOURS", 23).to_f
  end

  def self.runs_per_cycle
    window = window_hours.hours
    interval = interval_minutes.minutes
    [(window / interval).floor, 1].max
  end

  def self.batch_size
    total = Product.where.not(source_url: nil).count
    raw = (total.to_f / runs_per_cycle).ceil
    raw.clamp(1, max_batch)
  end

  def self.stale_after
    stale_hours.hours
  end
end
