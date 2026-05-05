class ApplicationMailer < ActionMailer::Base
  default from: -> { ENV.fetch("MAILER_FROM", "no-reply@pricetracker.example") }
  layout "mailer"
end
