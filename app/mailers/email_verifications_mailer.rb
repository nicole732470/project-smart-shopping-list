class EmailVerificationsMailer < ApplicationMailer
  def code(user, code)
    @user = user
    @code = code

    mail subject: "Verify your PriceTracker account", to: user.email_address
  end
end
