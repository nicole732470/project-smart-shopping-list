namespace :mailer do
  desc "Send a sample price-drop alert (requires SMTP_ADDRESS + SMTP_PASSWORD)"
  task smoke_test: :environment do
    unless MailerSettings.smtp_configured?
      abort "Set SMTP_ADDRESS and SMTP_PASSWORD (and MAILER_FROM, APP_URL) before running this task."
    end

    user = User.order(:id).first
    abort "No users in database." unless user

    product = user.products.where.not(target_price: nil).first ||
              user.products.create!(
                name: "Mailer smoke test product",
                category: "Electronics",
                target_price: 99.99,
                source_url: "https://www.amazon.com/dp/B091G65HH6"
              )

    record = product.price_records.create!(
      price: product.target_price || 49.99,
      store_name: "Smoke Test Store",
      recorded_at: Time.current,
      source: "manual"
    )

    PriceRecord.alerter_callback_enabled = false
    mail = PriceAlertMailer.price_drop(product, record, reasons: [ :target_hit ])
    mail.deliver_now
    puts "Sent price alert email to #{user.email_address}"
  ensure
    PriceRecord.alerter_callback_enabled = true
  end
end
