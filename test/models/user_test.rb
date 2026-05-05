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
end
