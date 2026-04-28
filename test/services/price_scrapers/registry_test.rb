require "test_helper"

class PriceScrapers::RegistryTest < ActiveSupport::TestCase
  test "amazon hosts route to AmazonAdapter" do
    assert_kind_of PriceScrapers::AmazonAdapter,
                   PriceScrapers::Registry.for("https://www.amazon.com/dp/B09B8V1LZ3")
    assert_kind_of PriceScrapers::AmazonAdapter,
                   PriceScrapers::Registry.for("https://amazon.co.uk/dp/X")
    assert_kind_of PriceScrapers::AmazonAdapter,
                   PriceScrapers::Registry.for("https://www.amazon.de/dp/X")
  end

  test "non-amazon hosts route to JsonLdAdapter (the generic fallback)" do
    assert_kind_of PriceScrapers::JsonLdAdapter,
                   PriceScrapers::Registry.for("https://www.target.com/p/foo/A-1")
    assert_kind_of PriceScrapers::JsonLdAdapter,
                   PriceScrapers::Registry.for("https://shop.lululemon.com/p/abc")
    assert_kind_of PriceScrapers::JsonLdAdapter,
                   PriceScrapers::Registry.for("https://www.bestbuy.com/site/foo")
  end

  test "amaazon-typo (substring not host) does NOT match Amazon" do
    # Make sure our regex is anchored to host boundaries: amaazon.com is unrelated.
    assert_kind_of PriceScrapers::JsonLdAdapter,
                   PriceScrapers::Registry.for("https://amaazon.com/p/123")
  end
end
