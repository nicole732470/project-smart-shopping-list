require "test_helper"

class MailerSettingsTest < ActiveSupport::TestCase
  setup do
    @original = %w[
      SMTP_ADDRESS SMTP_PORT SMTP_USERNAME SMTP_PASSWORD
      MAILER_FROM APP_URL MAILER_HOST MAILER_PROTOCOL
    ].index_with { |key| ENV[key] }
  end

  teardown do
    @original.each { |key, val| val.nil? ? ENV.delete(key) : ENV[key] = val }
  end

  test "smtp_configured? is true when address and password are present" do
    ENV["SMTP_ADDRESS"] = "smtp.sendgrid.net"
    ENV["SMTP_PASSWORD"] = "secret"
    assert MailerSettings.smtp_configured?
  end

  test "smtp_configured? is false when password is missing" do
    ENV["SMTP_ADDRESS"] = "smtp.sendgrid.net"
    ENV.delete("SMTP_PASSWORD")
    refute MailerSettings.smtp_configured?
  end

  test "default_url_options uses APP_URL host and https" do
    ENV["APP_URL"] = "https://smart-shoppinglist.example.herokuapp.com"
    assert_equal(
      { host: "smart-shoppinglist.example.herokuapp.com", protocol: "https" },
      MailerSettings.default_url_options
    )
  end

  test "smtp_settings uses SendGrid defaults" do
    ENV["SMTP_ADDRESS"] = "smtp.sendgrid.net"
    ENV["SMTP_PASSWORD"] = "sg-key"
    settings = MailerSettings.smtp_settings
    assert_equal "smtp.sendgrid.net", settings[:address]
    assert_equal 587, settings[:port]
    assert_equal "apikey", settings[:user_name]
    assert_equal "sg-key", settings[:password]
  end

  test "from_address falls back when MAILER_FROM is unset" do
    ENV.delete("MAILER_FROM")
    assert_equal "PriceTracker <noreply@example.com>", MailerSettings.from_address
  end
end
