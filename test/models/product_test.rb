require "test_helper"

class ProductTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @product = @user.products.build(name: "Test Product", category: "Electronics")
  end

  test "valid product" do
    assert @product.valid?
  end

  test "invalid without name" do
    @product.name = ""
    assert_not @product.valid?
  end

  test "invalid without category" do
    @product.category = ""
    assert_not @product.valid?
  end

  test "lowest_price returns nil when no records" do
    @product.save!
    assert_nil @product.lowest_price
  end

  test "latest_price returns most recent price" do
    @product.save!
    @product.price_records.create!(price: 100, store_name: "Amazon", recorded_at: 2.days.ago)
    @product.price_records.create!(price: 90, store_name: "Walmart", recorded_at: 1.day.ago)
    assert_equal 90, @product.latest_price
  end

  test "lowest_price returns minimum price" do
    @product.save!
    @product.price_records.create!(price: 120, store_name: "Amazon", recorded_at: 3.days.ago)
    @product.price_records.create!(price: 90, store_name: "Walmart", recorded_at: 2.days.ago)
    @product.price_records.create!(price: 105, store_name: "Target", recorded_at: 1.day.ago)
    assert_equal 90, @product.lowest_price
  end
end