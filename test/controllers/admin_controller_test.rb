require "test_helper"

class AdminControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  GOOD_TOKEN = "test-admin-secret-do-not-use-in-prod".freeze

  setup do
    @original_token = ENV["ADMIN_REFRESH_TOKEN"]
    ENV["ADMIN_REFRESH_TOKEN"] = GOOD_TOKEN
  end

  teardown do
    if @original_token.nil?
      ENV.delete("ADMIN_REFRESH_TOKEN")
    else
      ENV["ADMIN_REFRESH_TOKEN"] = @original_token
    end
  end

  test "POST /admin/refresh_prices without any token is 401" do
    assert_no_enqueued_jobs only: RefreshPricesJob do
      post "/admin/refresh_prices"
    end
    assert_response :unauthorized
  end

  test "POST /admin/refresh_prices with a wrong token is 401" do
    assert_no_enqueued_jobs only: RefreshPricesJob do
      post "/admin/refresh_prices", headers: { "X-Admin-Token" => "totally-wrong" }
    end
    assert_response :unauthorized
  end

  test "POST /admin/refresh_prices with a blank token is 401" do
    assert_no_enqueued_jobs only: RefreshPricesJob do
      post "/admin/refresh_prices", headers: { "X-Admin-Token" => "" }
    end
    assert_response :unauthorized
  end

  test "POST /admin/refresh_prices is 401 when ADMIN_REFRESH_TOKEN is unset (fail-closed)" do
    ENV.delete("ADMIN_REFRESH_TOKEN")
    assert_no_enqueued_jobs only: RefreshPricesJob do
      post "/admin/refresh_prices", headers: { "X-Admin-Token" => GOOD_TOKEN }
    end
    assert_response :unauthorized
  end

  test "POST /admin/refresh_prices does not require a logged-in session" do
    assert_enqueued_with(job: RefreshPricesJob) do
      post "/admin/refresh_prices", headers: { "X-Admin-Token" => GOOD_TOKEN }
    end
    assert_response :accepted
  end

  test "POST /admin/refresh_prices with the right token enqueues RefreshPricesJob and returns 202" do
    assert_difference "PriceRefreshRun.count", 1 do
      assert_enqueued_with(job: RefreshPricesJob) do
        post "/admin/refresh_prices",
             headers: {
               "X-Admin-Token" => GOOD_TOKEN,
               "X-Trigger-Source" => "manual"
             }
      end
    end

    assert_response :accepted
    body = JSON.parse(response.body)
    assert_equal true, body["ok"]
    assert_equal "enqueued", body["status"]
    assert body["run_id"].present?
    assert_equal "batch", body["mode"]
    assert_equal RefreshSchedule.batch_size, body["batch_size"]
    assert_equal RefreshSchedule.runs_per_cycle, body["runs_per_cycle"]

    run = PriceRefreshRun.find(body["run_id"])
    assert_equal "manual", run.triggered_by
    assert_equal "pending", run.status
  end

  test "POST with X-Refresh-Mode full-cycle enqueues job in full-cycle mode" do
    assert_enqueued_with(job: RefreshPricesJob, args: ->(args) {
      args.length == 2 && args[1][:full_cycle] == true
    }) do
      post "/admin/refresh_prices",
           headers: {
             "X-Admin-Token" => GOOD_TOKEN,
             "X-Refresh-Mode" => "full-cycle"
           }
    end

    assert_response :accepted
    body = JSON.parse(response.body)
    assert_equal "full_cycle", body["mode"]
  end

  test "GET /admin/refresh_runs/:id returns run JSON with admin token" do
    run = PriceRefreshRun.create!(
      triggered_by: "schedule",
      status: "completed",
      batch_size: 10,
      attempted: 5,
      succeeded: 4,
      failed: 1,
      enqueued_at: Time.current,
      finished_at: Time.current,
      failure_details: [ { "product_id" => 1, "name" => "X", "error" => "timeout" } ]
    )

    get "/admin/refresh_runs/#{run.id}", headers: { "X-Admin-Token" => GOOD_TOKEN }
    assert_response :success

    body = JSON.parse(response.body)
    assert_equal run.id, body["id"]
    assert_equal "schedule", body["triggered_by"]
    assert_equal "completed", body["status"]
    assert_equal 4, body["succeeded"]
    assert_equal 1, body["failed"]
    assert_equal 1, body["failure_details"].size
  end

  test "GET /admin/refresh_runs/:id without token is 401" do
    run = PriceRefreshRun.create!(
      triggered_by: "schedule",
      status: "pending",
      enqueued_at: Time.current
    )

    get "/admin/refresh_runs/#{run.id}"
    assert_response :unauthorized
  end
end
