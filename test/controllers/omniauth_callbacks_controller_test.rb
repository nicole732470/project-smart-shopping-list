require "test_helper"

class OmniauthCallbacksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @auth_hash = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: "controller-google-123",
      info: {
        email: "controller-oauth@example.com",
        name: "Controller OAuth",
        image: "https://example.com/controller.png"
      }
    )
  end

  test "google callback signs in a new oauth user" do
    assert_difference("User.count") do
      get "/auth/google_oauth2/callback", env: { "omniauth.auth" => @auth_hash }
    end

    assert_redirected_to root_path
    assert cookies[:session_id]
    assert_equal "google_oauth2", User.find_by(email_address: "controller-oauth@example.com").provider
  end

  test "google callback links an existing password account with the same email" do
    existing = User.create!(
      email_address: "controller-oauth@example.com",
      password: "Test#Pass9!",
      password_confirmation: "Test#Pass9!"
    )
    existing.products.create!(name: "Existing product", category: "Books")

    assert_no_difference("User.count") do
      get "/auth/google_oauth2/callback", env: { "omniauth.auth" => @auth_hash }
    end

    existing.reload
    assert_equal "google_oauth2", existing.provider
    assert_equal "controller-google-123", existing.uid
    assert_equal 1, existing.products.count
    assert_redirected_to root_path
  end

  test "oauth failure redirects to sign in" do
    get "/auth/failure"

    assert_redirected_to new_session_path
  end
end
