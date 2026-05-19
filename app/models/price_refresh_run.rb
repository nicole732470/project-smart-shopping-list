class PriceRefreshRun < ApplicationRecord
  TERMINAL_STATUSES = %w[completed skipped_overlap failed].freeze

  validates :triggered_by, presence: true
  validates :status, presence: true
  validates :enqueued_at, presence: true

  scope :recent, -> { order(enqueued_at: :desc) }

  def terminal?
    TERMINAL_STATUSES.include?(status)
  end

  def apply_summary!(summary)
    update!(
      status: "completed",
      total_products: summary[:total],
      catalog_with_url: summary[:catalog_with_url],
      batch_size: summary[:batch_size],
      batches_run: summary[:batches_run] || 1,
      attempted: summary[:attempted],
      succeeded: summary[:succeeded],
      failed: summary[:failed],
      stale_remaining: summary[:stale_remaining],
      duration_seconds: summary[:duration],
      failure_details: summary[:failures] || [],
      finished_at: Time.current
    )
  end

  def as_api_json
    {
      id: id,
      triggered_by: triggered_by,
      status: status,
      total_products: total_products,
      catalog_with_url: catalog_with_url,
      batch_size: batch_size,
      batches_run: batches_run,
      attempted: attempted,
      succeeded: succeeded,
      failed: failed,
      stale_remaining: stale_remaining,
      duration_seconds: duration_seconds&.to_f,
      failure_details: failure_details,
      error_message: error_message,
      enqueued_at: enqueued_at&.iso8601,
      started_at: started_at&.iso8601,
      finished_at: finished_at&.iso8601
    }
  end
end
