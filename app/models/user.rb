class User < ApplicationRecord
  EMAIL_VERIFICATION_CODE_TTL = 15.minutes

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :products, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address,
            presence: true,
            uniqueness: { case_sensitive: false },
            format: { with: URI::MailTo::EMAIL_REGEXP, message: "must be a valid email address" }

  def email_verified?
    email_verified_at.present?
  end

  def issue_email_verification_code!
    code = SecureRandom.random_number(1_000_000).to_s.rjust(6, "0")

    update!(
      email_verification_code_digest: BCrypt::Password.create(code),
      email_verification_sent_at: Time.current
    )

    code
  end

  def verify_email_code?(code)
    return false if code.blank? || email_verification_code_digest.blank?
    return false if email_verification_sent_at.blank?
    return false if email_verification_sent_at < EMAIL_VERIFICATION_CODE_TTL.ago

    BCrypt::Password.new(email_verification_code_digest).is_password?(code.to_s.strip)
  end

  def mark_email_verified!
    update!(
      email_verified_at: Time.current,
      email_verification_code_digest: nil,
      email_verification_sent_at: nil
    )
  end
end
