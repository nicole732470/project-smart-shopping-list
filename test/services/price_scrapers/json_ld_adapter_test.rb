require "test_helper"

class PriceScrapers::JsonLdAdapterTest < ActiveSupport::TestCase
  def fixture(name)
    Rails.root.join("test/fixtures/scrapers", name).read
  end

  def parse(name, url: "https://www.example.com/p/12345")
    doc = Nokogiri::HTML(fixture(name))
    PriceScrapers::JsonLdAdapter.new.parse(doc, url)
  end

  test "extracts price, title, and image from a Target-style JSON-LD page" do
    result = parse("json_ld_target.html", url: "https://www.target.com/p/airpods/A-12345")
    assert_equal BigDecimal("249.99"), result.price
    assert_equal "USD", result.currency
    assert_equal "Apple AirPods Pro (2nd Generation)", result.title
    assert_match %r{target\.scene7\.com}, result.image_url
  end

  test "handles array-of-objects with extra non-Product nodes (Lululemon-style)" do
    result = parse("json_ld_lululemon.html", url: "https://shop.lululemon.com/p/align/123")
    assert_equal BigDecimal("118.00"), result.price
    assert_equal 'Align High-Rise Pant 28"', result.title
    assert_match %r{lululemon\.com}, result.image_url
  end

  test "handles @graph wrapper and AggregateOffer" do
    result = parse("json_ld_aggregate.html")
    assert_equal BigDecimal("19.99"), result.price
    assert_equal "Generic Widget", result.title
    assert_equal "https://example.com/widget.jpg", result.image_url
  end

  test "raises PermanentError when no Product JSON-LD is found" do
    assert_raises(PriceScrapers::PermanentError) do
      parse("json_ld_missing.html")
    end
  end

  test "handles ProductGroup with offers nested under hasVariant (Lululemon-style)" do
    result = parse("json_ld_product_group.html",
                   url: "https://shop.lululemon.com/p/foo/qek715w0hh")
    assert_equal BigDecimal("148.00"), result.price
    assert_equal "USD", result.currency
    assert_equal 'lululemon Align™ Ribbed-Trim Cami Dress', result.title
    assert_match %r{lululemon\.com}, result.image_url
  end
end
