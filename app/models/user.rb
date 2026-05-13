class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :products, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address,
            presence: true,
            uniqueness: { case_sensitive: false },
            format: { with: URI::MailTo::EMAIL_REGEXP, message: "must be a valid email address" }

  validates :password, length: { minimum: 8, message: "must be at least 8 characters" }, if: -> { password.present? }
  validate :password_strength, if: -> { password.present? }

  private

  COMMON_PASSWORDS = %w[password password1 password123 12345678 qwerty123 letmein welcome].freeze

  def password_strength
    pwd = password.to_s

    unless pwd.match?(/[^A-Za-z0-9]/)
      errors.add(:password, "must contain at least one special character (e.g. !, @, #)")
    end

    if pwd.match?(/(.)\1{2,}/)
      errors.add(:password, "must not contain three or more repeated characters in a row")
    end

    if email_address.present?
      username = email_address.split("@").first.downcase
      if pwd.downcase.include?(username)
        errors.add(:password, "must not contain your email address")
      end
    end

    if COMMON_PASSWORDS.include?(pwd.downcase)
      errors.add(:password, "is too common — please choose a more unique password")
    end
  end
end
