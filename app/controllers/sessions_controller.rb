class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "Try again later." }

  def new
  end

  def create
    if user = User.authenticate_by(params.permit(:email_address, :password))
      unless user.email_verified?
        code = user.issue_email_verification_code!
        session[:pending_email_address] = user.email_address
        EmailVerificationsMailer.code(user, code).deliver_later

        return redirect_to new_email_verification_path(email_address: user.email_address),
                           alert: "Please verify your email first. We sent you a new code."
      end

      start_new_session_for user
      redirect_to after_authentication_url, notice: "Signed in."
    else
      redirect_to new_session_path, alert: "Try another email address or password."
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path, status: :see_other, notice: "Signed out."
  end
end
