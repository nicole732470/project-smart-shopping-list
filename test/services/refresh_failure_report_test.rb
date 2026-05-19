require "test_helper"

class RefreshFailureReportTest < ActiveSupport::TestCase
  test "aggregates failures by category, host, and error message" do
    report = RefreshFailureReport.new
    report.record_all([
      {
        "product_id" => 1,
        "name" => "A",
        "source_url" => "https://www.amazon.com/dp/B1",
        "host" => "www.amazon.com",
        "user_email" => "a@example.com",
        "error" => "HTTP 403 from www.amazon.com"
      },
      {
        "product_id" => 2,
        "name" => "B",
        "source_url" => "https://www.amazon.com/dp/B2",
        "host" => "www.amazon.com",
        "user_email" => "paginationtest@example.com",
        "error" => "HTTP 403 from www.amazon.com"
      },
      {
        "product_id" => 3,
        "name" => "C",
        "source_url" => "https://shop.lululemon.com/p/x",
        "host" => "shop.lululemon.com",
        "user_email" => "user@example.com",
        "error" => "HTTP 404 from shop.lululemon.com"
      }
    ])

    result = report.to_h
    assert_equal 3, result["total_failures"]
    assert_equal 2, result["by_category"].size
    assert_equal "HTTP 403 — blocked (bot/WAF)", result["by_category"].first["label"]
    assert_equal 2, result["by_category"].first["count"]
    assert_equal "www.amazon.com", result["by_host"].first["label"]
    assert_equal 2, result["samples"].size
    assert_equal "https://www.amazon.com/dp/B1", result["samples"].first["source_url"]
  end
end
