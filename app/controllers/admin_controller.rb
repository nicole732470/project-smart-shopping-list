class AdminController < ApplicationController
  # External cron (GitHub Actions) calls this with no session and no CSRF
  # token — it authenticates with a shared secret in the `X-Admin-Token`
  # header. Skip the cookie-based auth + CSRF protection accordingly.
  allow_unauthenticated_access only: :refresh_prices
  skip_forgery_protection only: :refresh_prices

  before_action :authenticate_admin_token!, only: :refresh_prices

  # POST /admin/refresh_prices
  #
  # Enqueues a batched background refresh and returns immediately (202).
  # Heroku web requests must finish within 30s; scraping thousands of
  # products serially exceeds that, so the actual work runs in
  # RefreshPricesJob on the web dyno's async adapter.
  def refresh_prices
    RefreshPricesJob.perform_later
    render json: {
      ok: true,
      status: "enqueued",
      batch_size: RefreshSchedule.batch_size,
      runs_per_cycle: RefreshSchedule.runs_per_cycle
    }, status: :accepted
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
