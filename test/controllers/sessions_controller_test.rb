require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = User.take }

  test "new" do
    get new_session_path
    assert_response :success
  end

  test "create with valid credentials" do
    post session_path, params: { email_address: @user.email_address, password: "password" }

    assert_redirected_to root_path
    assert cookies[:session_id]
  end

  test "create with unverified account sends code instead of signing in" do
    @user.update!(email_verified_at: nil)

    assert_enqueued_emails 1 do
      post session_path, params: { email_address: @user.email_address, password: "password" }
    end

    assert_redirected_to new_email_verification_path(email_address: @user.email_address)
    assert_nil cookies[:session_id]
    assert @user.reload.email_verification_code_digest.present?
  end

  test "create with invalid credentials" do
    post session_path, params: { email_address: @user.email_address, password: "wrong" }

    assert_redirected_to new_session_path
    assert_nil cookies[:session_id]
  end

  test "destroy" do
    sign_in_as(User.take)

    delete session_path

    assert_redirected_to new_session_path
    assert_empty cookies[:session_id]
  end
end
