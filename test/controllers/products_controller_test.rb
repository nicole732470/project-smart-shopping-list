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

  test "category filter limits results to matching category" do
    @user.products.create!(name: "Atomic Habits", category: "Books")
    @user.products.create!(name: "Sony Headphones", category: "Electronics")

    get products_url, params: { category: "Books" }
    assert_response :success
    assert_match "Atomic Habits",   response.body
    assert_no_match "Sony Headphones", response.body
  end

  test "sort by name_asc orders alphabetically" do
    @user.products.destroy_all
    @user.products.create!(name: "Banana Phone", category: "Electronics")
    @user.products.create!(name: "Apple Phone",  category: "Electronics")
    @user.products.create!(name: "Cherry Phone", category: "Electronics")

    get products_url, params: { sort: "name_asc" }
    assert_response :success
    body = response.body
    assert body.index("Apple Phone")  < body.index("Banana Phone")
    assert body.index("Banana Phone") < body.index("Cherry Phone")
  end

  test "empty state appears when user has no products" do
    @user.products.destroy_all
    get products_url
    assert_response :success
    assert_match "No products yet", response.body
  end

  test "no-match state appears when filters return nothing" do
    get products_url, params: { search: "this-string-will-never-match" }
    assert_response :success
    assert_match "No products match", response.body
  end

  # --- Target price + alert banner ---

  test "update can set target_price" do
    patch product_url(@product), params: { product: { target_price: "75.50" } }
    assert_redirected_to product_url(@product)
    assert_in_delta 75.50, @product.reload.target_price.to_f, 0.001
  end

  test "update can clear target_price by submitting blank" do
    @product.update_columns(target_price: 100)
    patch product_url(@product), params: { product: { target_price: "" } }
    assert_redirected_to product_url(@product)
    assert_nil @product.reload.target_price
  end

  test "show displays the target price meta when set" do
    @product.update_columns(target_price: 99.99)
    get product_url(@product)
    assert_response :success
    assert_match "Notify at", response.body
    assert_match "99.99", response.body
  end

  test "show renders alert banner when an alert fired recently" do
    @product.update_columns(target_price: 100, last_alerted_at: 2.days.ago)
    @product.price_records.create!(
      price: 80, store_name: "Best Buy", recorded_at: 2.days.ago - 1.minute
    )
    get product_url(@product)
    assert_response :success
    assert_match "PRICE ALERT TRIGGERED", response.body
    assert_match "Best Buy", response.body
  end

  test "show does not render alert banner for stale alerts" do
    @product.update_columns(target_price: 100, last_alerted_at: 10.days.ago)
    get product_url(@product)
    assert_response :success
    assert_no_match "PRICE ALERT TRIGGERED", response.body
  end

  test "show does not render alert banner when nothing has fired" do
    @product.update_columns(target_price: 100, last_alerted_at: nil)
    get product_url(@product)
    assert_response :success
    assert_no_match "PRICE ALERT TRIGGERED", response.body
  end

  test "index card shows target chip when target_price is set and no recent alert" do
    @product.update_columns(target_price: 49.99, last_alerted_at: nil)
    get products_url
    assert_response :success
    assert_match "Notify at", response.body
    assert_match "49.99", response.body
  end

  test "index card shows alert-fired chip when alert is recent" do
    @product.update_columns(target_price: 100, last_alerted_at: 1.day.ago)
    get products_url
    assert_response :success
    assert_match "Alert fired", response.body
  end
end
