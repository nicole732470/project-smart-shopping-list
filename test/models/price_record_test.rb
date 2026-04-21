require "test_helper"

class PriceRecordTest < ActiveSupport::TestCase
  def setup
    @product = users(:one).products.create!(name: "Test Product", category: "Electronics")
    @record = PriceRecord.new(
      product: @product,
      price: 99.99,
      store_name: "Amazon",
      url: "https://www.amazon.com/test",
      recorded_at: Time.current
    )
  end

  test "valid price record" do
    assert @record.valid?
  end

  test "invalid without price" do
    @record.price = nil
    assert_not @record.valid?
  end

  test "invalid with zero price" do
    @record.price = 0
    assert_not @record.valid?
  end

  test "invalid with negative price" do
    @record.price = -5
    assert_not @record.valid?
  end

  test "invalid without store_name" do
    @record.store_name = ""
    assert_not @record.valid?
  end

  test "url is optional" do
    @record.url = nil
    assert @record.valid?
  end

  test "belongs to product" do
    assert_equal @product, @record.product
  end
end