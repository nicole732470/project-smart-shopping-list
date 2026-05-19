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
    assert_enqueued_with(job: RefreshPricesJob) do
      post "/admin/refresh_prices", headers: { "X-Admin-Token" => GOOD_TOKEN }
    end

    assert_response :accepted
    body = JSON.parse(response.body)
    assert_equal true, body["ok"]
    assert_equal "enqueued", body["status"]
    assert_equal RefreshSchedule.batch_size, body["batch_size"]
    assert_equal RefreshSchedule.runs_per_cycle, body["runs_per_cycle"]
  end
end
