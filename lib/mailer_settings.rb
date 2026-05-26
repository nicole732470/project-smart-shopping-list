# Shared Action Mailer configuration driven by ENV.
#
# Production (and development when testing) sends real mail when SMTP_* vars
# are set — typically SendGrid on Heroku:
#
#   SMTP_ADDRESS=smtp.sendgrid.net
#   SMTP_USERNAME=apikey
#   SMTP_PASSWORD=<SendGrid API key>
#   MAILER_FROM="PriceTracker <you@verified-sender.com>"
#   APP_URL=https://smart-shoppinglist-....herokuapp.com
module MailerSettings
  module_function

  def apply!(config)
    config.action_mailer.default_url_options = default_url_options if default_url_options.present?
    config.action_mailer.default_options = { from: from_address }

    return unless smtp_configured?

    config.action_mailer.delivery_method = :smtp
    config.action_mailer.smtp_settings = smtp_settings
    config.action_mailer.perform_deliveries = true
    config.action_mailer.raise_delivery_errors = true
  end

  def smtp_configured?
    ENV["SMTP_ADDRESS"].present? && ENV["SMTP_PASSWORD"].present?
  end

  def from_address
    ENV["MAILER_FROM"].presence || "PriceTracker <noreply@example.com>"
  end

  def default_url_options
    host = mailer_host
    return {} if host.blank?

    { host: host, protocol: mailer_protocol }
  end

  def mailer_host
    return ENV["MAILER_HOST"] if ENV["MAILER_HOST"].present?
    return nil if ENV["APP_URL"].blank?

    URI.parse(ENV["APP_URL"]).host
  rescue URI::InvalidURIError
    nil
  end

  def mailer_protocol
    return ENV["MAILER_PROTOCOL"] if ENV["MAILER_PROTOCOL"].present?
    return "https" if ENV["APP_URL"].to_s.start_with?("https")

    "http"
  end

  def smtp_settings
    {
      address: ENV.fetch("SMTP_ADDRESS"),
      port: ENV.fetch("SMTP_PORT", "587").to_i,
      user_name: ENV.fetch("SMTP_USERNAME", "apikey"),
      password: ENV.fetch("SMTP_PASSWORD"),
      authentication: :plain,
      enable_starttls_auto: true
    }
  end
end
