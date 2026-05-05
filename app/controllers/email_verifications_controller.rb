class EmailVerificationsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]

  def new
    @email_address = params[:email_address].presence || session[:pending_email_address]
  end

  def create
    @email_address = verification_params[:email_address].to_s.strip.downcase
    @user = User.find_by(email_address: @email_address)

    if @user&.verify_email_code?(verification_params[:code])
      @user.mark_email_verified!
      session.delete(:pending_email_address)
      start_new_session_for @user
      redirect_to root_path, notice: "Email verified. Welcome!"
    else
      flash.now[:alert] = "That verification code is invalid or has expired."
      render :new, status: :unprocessable_entity
    end
  end

  private

  def verification_params
    params.permit(:email_address, :code)
  end
end
