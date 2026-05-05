class RegistrationsController < ApplicationController
  allow_unauthenticated_access only: [ :new, :create ]

  def new
    @user = User.new
  end

  def create
    @user = User.new(registration_params)
    if @user.save
      send_email_verification_code(@user)
      redirect_to new_email_verification_path(email_address: @user.email_address),
                  notice: "Account created. We sent a verification code to your email."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def registration_params
    params.require(:user).permit(:email_address, :password, :password_confirmation)
  end

  def send_email_verification_code(user)
    code = user.issue_email_verification_code!
    session[:pending_email_address] = user.email_address
    EmailVerificationsMailer.code(user, code).deliver_later
  end
end
