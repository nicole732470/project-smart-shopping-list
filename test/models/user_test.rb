require "test_helper"

class UserTest < ActiveSupport::TestCase
  def valid_attributes(overrides = {})
    {
      email_address: "person@example.com",
      password: "password",
      password_confirmation: "password"
    }.merge(overrides)
  end

  test "valid with email + password" do
    assert User.new(valid_attributes).valid?
  end

  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal "downcased@example.com", user.email_address
  end

  test "invalid without email_address" do
    user = User.new(valid_attributes(email_address: ""))
    assert_not user.valid?
    assert_includes user.errors[:email_address], "can't be blank"
  end

  test "invalid with malformed email_address" do
    user = User.new(valid_attributes(email_address: "not-an-email"))
    assert_not user.valid?
    assert_includes user.errors[:email_address].join, "valid email"
  end

  test "rejects duplicate email_address (case-insensitive)" do
    User.create!(valid_attributes(email_address: "dup@example.com"))
    dup = User.new(valid_attributes(email_address: "DUP@example.com"))
    assert_not dup.valid?
    assert_includes dup.errors[:email_address], "has already been taken"
  end

  test "invalid without password" do
    user = User.new(valid_attributes.merge(password: "", password_confirmation: ""))
    assert_not user.valid?
  end

  test "issues and verifies email verification code" do
    user = User.create!(valid_attributes.merge(email_address: "verify@example.com"))
    code = user.issue_email_verification_code!

    assert_match(/\A\d{6}\z/, code)
    assert user.verify_email_code?(code)
    assert_not user.verify_email_code?("000000")
  end

  test "email verification code expires" do
    user = User.create!(valid_attributes.merge(email_address: "expired@example.com"))
    code = user.issue_email_verification_code!
    user.update!(email_verification_sent_at: 20.minutes.ago)

    assert_not user.verify_email_code?(code)
  end

  test "mark_email_verified clears pending code" do
    user = User.create!(valid_attributes.merge(email_address: "marked@example.com"))
    user.issue_email_verification_code!

    user.mark_email_verified!

    assert user.email_verified?
    assert_nil user.email_verification_code_digest
    assert_nil user.email_verification_sent_at
  end
end
