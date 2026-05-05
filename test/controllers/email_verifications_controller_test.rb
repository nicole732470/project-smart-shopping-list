require "test_helper"

class EmailVerificationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @user.update!(email_verified_at: nil)
    @code = @user.issue_email_verification_code!
  end

  test "new" do
    get new_email_verification_path(email_address: @user.email_address)
    assert_response :success
    assert_select "input[value=?]", @user.email_address
  end

  test "create verifies email and signs user in with valid code" do
    post email_verification_path, params: {
      email_address: @user.email_address,
      code: @code
    }

    assert_redirected_to root_path
    assert cookies[:session_id]
    assert @user.reload.email_verified?
    assert_nil @user.email_verification_code_digest
  end

  test "create rejects invalid code" do
    post email_verification_path, params: {
      email_address: @user.email_address,
      code: "123456"
    }

    assert_response :unprocessable_entity
    assert_nil cookies[:session_id]
    assert_not @user.reload.email_verified?
  end
end
