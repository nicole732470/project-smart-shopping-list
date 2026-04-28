require "test_helper"

class ProductsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @product = products(:one)
    sign_in_as @user
  end

  test "should get index" do
    get products_url
    assert_response :success
  end

  test "should get new" do
    get new_product_url
    assert_response :success
  end

  test "should create product" do
    fake_result = PriceScrapers::Result.new(
      price:      BigDecimal("9.99"),
      currency:   "USD",
      title:      "Stubbed Test Product",
      image_url:  "https://example.com/x.jpg",
      store_name: "Example",
      fetched_at: Time.current
    )
    stub_method(PriceScrapers, :fetch, ->(_url, **_opts) { fake_result }) do
      assert_difference("Product.count") do
        post products_url, params: {
          product: { source_url: "https://www.example.com/p/123", category: "Electronics" }
        }
      end
    end
    assert_redirected_to product_url(Product.last)
    assert_equal "Stubbed Test Product", Product.last.name
    assert_equal "scraped", Product.last.price_records.first.source
  end

  test "should show product" do
    get product_url(@product)
    assert_response :success
  end

  test "should get edit" do
    get edit_product_url(@product)
    assert_response :success
  end

  test "should update product" do
    patch product_url(@product), params: { product: { name: "Updated" } }
    assert_redirected_to product_url(@product)
  end

  test "should destroy product" do
    assert_difference("Product.count", -1) do
      delete product_url(@product)
    end
    assert_redirected_to products_url
  end

  test "should not show another user's product" do
    other = products(:two)
    get product_url(other)
    assert_response :not_found
  end

  test "should redirect unauthenticated user to sign in" do
    sign_out
    get products_url
    assert_redirected_to new_session_url
  end

  test "search is case-insensitive and matches partial words" do
    @user.products.create!(name: "Apple iPhone 15 Pro", category: "Electronics", description: "phone")
    @user.products.create!(name: "Atomic Habits", category: "Books", description: "self help")

    get products_url, params: { search: "iphone" }
    assert_response :success
    assert_match "Apple iPhone 15 Pro", response.body
    assert_no_match "Atomic Habits", response.body
  end

  test "search matches across name, category, and description with multiple tokens" do
    @user.products.create!(name: "Sony Headphones", category: "Electronics", description: "wireless noise cancelling")
    @user.products.create!(name: "Wired Mouse", category: "Electronics", description: "USB device")

    get products_url, params: { search: "wireless electronics" }
    assert_response :success
    assert_match "Sony Headphones", response.body
    assert_no_match "Wired Mouse", response.body
  end
end
