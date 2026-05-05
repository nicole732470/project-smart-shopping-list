class AddEmailVerificationToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :email_verified_at, :datetime
    add_column :users, :email_verification_code_digest, :string
    add_column :users, :email_verification_sent_at, :datetime
  end
end
