class Product < ApplicationRecord
    # Column caps mirror the DB check constraints added in
    # HardenProductAndPriceRecordConstraints. Scraped Amazon / Target / etc.
    # titles routinely run past 200 chars; rather than reject the save and
    # show a validation error, we silently truncate in a before_validation
    # so every save path (scraper, manual form, seeds) stays within bounds.
    NAME_LIMIT        = 140
    CATEGORY_LIMIT    = 80
    DESCRIPTION_LIMIT = 1_000

    belongs_to :user
    has_many :price_records, dependent: :destroy

    before_validation :truncate_long_text_fields

    validates :name, presence: true
    validates :name, length: { maximum: NAME_LIMIT }
    validates :category, presence: true
    validates :category, length: { maximum: CATEGORY_LIMIT }
    validates :description, length: { maximum: DESCRIPTION_LIMIT }, allow_blank: true
    validates :image_url,
              length: { maximum: 2_000 },
              format: { with: %r{\Ahttps?://[^\s]+\z}i, message: "must start with http:// or https://" },
              allow_blank: true
    # source_url is optional at the model level so legacy / seed / manual-only
    # products remain valid. The new-product form makes it required at the UI
    # level (HTML required + ProductsController#create blank check).
    validates :source_url,
              length: { maximum: 2_000 },
              format: { with: %r{\Ahttps?://[^\s]+\z}i, message: "must start with http:// or https://" },
              allow_blank: true
    # target_price is opt-in: a nil value just means "no alert configured".
    # When set, it must be a positive number. We cap it at 10 million to keep
    # the column inside its decimal(10,2) precision.
    validates :target_price,
              numericality: { greater_than: 0, less_than_or_equal_to: 10_000_000 },
              allow_nil: true

    # True iff the owner has asked to be alerted when the price hits or
    # drops below `target_price`. Used by PriceAlerter to decide whether to
    # bother running the rest of the alert evaluation.
    def target_price_alert_enabled?
      target_price.present?
    end

    # Don't email the user more than once per `window`. The 24-hour default
    # matches PriceAlerter's expectations and gives us room to lengthen the
    # window later if users complain about noise.
    def alert_cooldown_active?(window: 24.hours)
      last_alerted_at.present? && last_alerted_at > window.ago
    end

    # Used by the product detail / index views to decide whether to render
    # the "🎉 Price alert triggered" banner / card chip. Defaults to 7 days
    # so the banner stays around long enough for the user to actually see
    # the deal but doesn't linger forever.
    def recent_alert?(window: 7.days)
      last_alerted_at.present? && last_alerted_at > window.ago
    end

    # Best-effort lookup of the PriceRecord whose creation fired the most
    # recent alert. PriceAlerter stamps `last_alerted_at = Time.current`
    # right after writing the PriceRecord, so the trigger record is the
    # latest one whose `recorded_at` is at or before that stamp.
    def alert_trigger_record
      return nil if last_alerted_at.blank?
      price_records.where("recorded_at <= ?", last_alerted_at)
                   .order(recorded_at: :desc)
                   .first
    end

    def lowest_price
      price_records.minimum(:price)
    end

    def lowest_price_record
      price_records.order(:price).first
    end

    def latest_price
      price_records.order(recorded_at: :desc).first&.price
    end

    def latest_store
      price_records.order(recorded_at: :desc).first&.store_name
    end

    # Calculate price trend based on latest price vs historical average.
    # Returns :up (price increased), :down (price decreased), :stable (relatively unchanged), or nil
    def price_trend
      records = price_records.order(recorded_at: :asc)
      return nil if records.count < 2

      latest = records.last.price
      # Compare against average of all previous prices
      previous_avg = records[0...-1].map(&:price).sum / (records.count - 1).to_f

      diff_percent = ((latest - previous_avg) / previous_avg * 100).abs

      case
      when latest > previous_avg && diff_percent > 5
        :up
      when latest < previous_avg && diff_percent > 5
        :down
      else
        :stable
      end
    end

    # Human-readable price trend indicator
    def price_trend_emoji
      case price_trend
      when :up
        "📈"
      when :down
        "📉"
      when :stable
        "➡️"
      else
        "❓"
      end
    end

    # Trend description for accessibility
    def price_trend_description
      case price_trend
      when :up
        "Price is trending up"
      when :down
        "Price is trending down"
      when :stable
        "Price is stable"
      else
        "Not enough data to determine trend"
      end
    end

    # Products with a source_url present (includes load-test / seed rows).
    scope :with_trackable_url, -> { where.not(source_url: [ nil, "" ]) }

    # Subset whose URLs point at real product pages we can scrape. Excludes:
    #   - example.com placeholders (pagination stress-test account)
    #   - retailer /search? URLs used by db/seeds.rb for volume, not PDPs
    scope :scrapeable, -> {
      with_trackable_url
        .where.not("source_url ILIKE ?", "%example.com%")
        .where.not("source_url ILIKE ?", "%/search?%")
        .where.not("source_url ILIKE ?", "%/s?k=%")
    }

    # Products the nightly/manual refresh should actually scrape. Omits the
    # pagination stress-test account — those rows exist for Pagy UI volume only.
    PAGINATION_TEST_EMAIL = "paginationtest@example.com"

    scope :refreshable, -> {
      scrapeable.joins(:user).where.not(users: { email_address: PAGINATION_TEST_EMAIL })
    }

    def self.scrape_excluded?(url)
      u = url.to_s
      return true if u.blank?
      return true if u.include?("example.com")
      return true if u.match?(%r{/search[?]}i) || u.match?(%r{/s[?]k=}i)

      false
    end

    def scrapeable?
      source_url.present? && !self.class.scrape_excluded?(source_url)
    end

    private

    # Trim scraped/oversized text to the column caps before validations
    # run so a 250-char Amazon title never causes a save to fail. An
    # ellipsis marker is appended to make truncation visible to the user.
    def truncate_long_text_fields
      truncate_field(:name,        NAME_LIMIT)
      truncate_field(:category,    CATEGORY_LIMIT)
      truncate_field(:description, DESCRIPTION_LIMIT)
    end

    def truncate_field(attr, limit)
      value = self[attr]
      return if value.blank?
      return if value.length <= limit

      self[attr] = value[0, limit - 1].rstrip + "…"
    end
end
