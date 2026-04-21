require "test_helper"

class PriceRecordsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @product = products(:one)
    @price_record = price_records(:one)
    sign_in_as @user
  end

  test "should get index" do
    get price_records_url
    assert_response :success
  end

  test "should show price record" do
    get price_record_url(@price_record)
    assert_response :success
  end

  test "should get new" do
    get new_product_price_record_url(@product)
    assert_response :success
  end

  test "should create price record" do
    assert_difference("PriceRecord.count") do
      post product_price_records_url(@product), params: {
        price_record: { price: 9.99, store_name: "Amazon", url: "https://example.com", notes: "test" }
      }
    end
  end

  test "should not access another user's price record" do
    other = price_records(:two)
    get price_record_url(other)
    assert_response :not_found
  end
end
