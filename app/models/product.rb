class Product < ApplicationRecord
    belongs_to :user
    has_many :price_records, dependent: :destroy

    validates :name, presence: true
    validates :category, presence: true
    # source_url is optional at the model level so legacy / seed / manual-only
    # products remain valid. The new-product form makes it required at the UI
    # level (HTML required + ProductsController#create blank check).
    validates :source_url,
              format: { with: %r{\Ahttps?://[^\s]+\z}i, message: "must start with http:// or https://" },
              allow_blank: true

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
