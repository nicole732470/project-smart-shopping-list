class AdminController < ApplicationController
  # External cron (GitHub Actions) calls these with no session and no CSRF
  # token — they authenticate with a shared secret in the `X-Admin-Token`
  # header. Skip the cookie-based auth + CSRF protection accordingly.
  allow_unauthenticated_access only: %i[refresh_prices refresh_run]
  skip_forgery_protection only: %i[refresh_prices refresh_run]

  before_action :authenticate_admin_token!, only: %i[refresh_prices refresh_run]

  # POST /admin/refresh_prices
  #
  # Enqueues a batched background refresh and returns immediately (202).
  # Heroku web requests must finish within 30s; scraping thousands of
  # products serially exceeds that, so the actual work runs in
  # RefreshPricesJob on the web dyno's async adapter.
  def refresh_prices
    full_cycle = request.headers["X-Refresh-Mode"].to_s == "full-cycle"

    run = PriceRefreshRun.create!(
      triggered_by: request.headers["X-Trigger-Source"].presence || "unknown",
      status: "pending",
      batch_size: RefreshSchedule.batch_size,
      enqueued_at: Time.current
    )

    RefreshPricesJob.perform_later(run.id, full_cycle: full_cycle)
    render json: {
      ok: true,
      status: "enqueued",
      mode: full_cycle ? "full_cycle" : "batch",
      run_id: run.id,
      batch_size: RefreshSchedule.batch_size,
      runs_per_cycle: RefreshSchedule.runs_per_cycle,
      refreshable_products: Product.refreshable.count
    }, status: :accepted
  end

  # GET /admin/refresh_runs/:id
  #
  # Poll endpoint for GitHub Actions after POST /admin/refresh_prices.
  def refresh_run
    run = PriceRefreshRun.find(params[:id])
    render json: run.as_api_json
  end

  private

  # Compare the provided token against ADMIN_REFRESH_TOKEN using a constant-
  # time comparison so we don't leak token contents via timing. We require
  # the env var to be present; if it isn't configured, every request is
  # rejected (fail-closed default).
  def authenticate_admin_token!
    expected = ENV["ADMIN_REFRESH_TOKEN"].to_s
    provided = request.headers["X-Admin-Token"].to_s

    authorized =
      expected.present? &&
      provided.present? &&
      ActiveSupport::SecurityUtils.secure_compare(provided, expected)

    head :unauthorized unless authorized
  end
end
