class Product < ApplicationRecord
    belongs_to :user
    has_many :price_records, dependent: :destroy

    validates :name, presence: true
    validates :category, presence: true

    def lowest_price
      price_records.minimum(:price)
    end

    def latest_price
      price_records.order(recorded_at: :desc).first&.price
    end

    def latest_store
      price_records.order(recorded_at: :desc).first&.store_name
    end
end
