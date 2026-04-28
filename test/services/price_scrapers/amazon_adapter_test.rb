require "test_helper"

class PriceScrapers::AmazonAdapterTest < ActiveSupport::TestCase
  def fixture(name)
    Rails.root.join("test/fixtures/scrapers", name).read
  end

  test "extracts price/title/image from a typical Amazon product page" do
    doc = Nokogiri::HTML(fixture("amazon_basic.html"))
    result = PriceScrapers::AmazonAdapter.new.parse(doc, "https://www.amazon.com/dp/B09B8V1LZ3")

    assert_equal BigDecimal("49.99"), result.price
    assert_equal "Echo Dot (5th Gen) Smart Speaker", result.title
    assert_equal "Amazon", result.store_name
    assert_match %r{echodot-large\.jpg}, result.image_url, "should prefer data-old-hires over src"
  end

  test "Result fields are nil for an empty document" do
    doc = Nokogiri::HTML("<html><body></body></html>")
    result = PriceScrapers::AmazonAdapter.new.parse(doc, "https://www.amazon.com/dp/X")
    assert_nil result.price
    assert_nil result.title
    assert_nil result.image_url
    assert_equal "Amazon", result.store_name
  end
end
