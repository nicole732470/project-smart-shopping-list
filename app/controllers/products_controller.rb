class ProductsController < ApplicationController
  before_action :set_product, only: [ :show, :edit, :update, :destroy, :fetch_price ]

  def index
    @products = Current.user.products.includes(:price_records)
    @products = fuzzy_search(@products, params[:search]) if params[:search].present?
    @products = @products.where(category: params[:category]) if params[:category].present?
    @products = sort_products(@products, params[:sort])

    @categories = Current.user.products.distinct.pluck(:category).compact.sort
  end

  def show
    @price_records = @product.price_records.order(recorded_at: :desc)
    @chart_data = build_chart_data(@price_records)
    @lowest_price_record = @product.lowest_price_record
  end

  def new
    @product = Current.user.products.build
    @manual  = ActiveModel::Type::Boolean.new.cast(params[:manual])
  end

  def create
    @product = Current.user.products.build(create_params)
    @manual  = ActiveModel::Type::Boolean.new.cast(params[:manual])

    # Manual mode: user filled in name/details by hand, skip the scraper.
    if @manual || @product.name.present?
      @manual = true
      if @product.save
        return redirect_to @product, notice: "Product added."
      else
        return render :new, status: :unprocessable_entity
      end
    end

    if @product.source_url.blank?
      @product.errors.add(:source_url, "can't be blank")
      return render :new, status: :unprocessable_entity
    end

    begin
      result = PriceScrapers.fetch(@product.source_url, timeout: 5)
    rescue PriceScrapers::Error => e
      @manual = true
      flash.now[:alert] = friendly_scrape_error(e) +
        " You can fill in the product details below to add it manually."
      return render :new, status: :unprocessable_entity
    end

    @product.name      = result.title.presence || fallback_name_from(@product.source_url)
    @product.image_url = result.image_url if result.image_url.present?

    if @product.save
      if result.price.present?
        @product.price_records.create!(
          price:       result.price,
          store_name:  result.store_name,
          url:         @product.source_url,
          recorded_at: result.fetched_at,
          source:      "scraped"
        )
      end
      @product.update_columns(last_fetched_at: Time.current, last_fetch_error: nil)
      redirect_to @product, notice: "Product added! We grabbed its details from the page."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @product.update(update_params)
      redirect_to @product, notice: "Product updated successfully!"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @product.destroy
    redirect_to products_url, notice: "Product deleted."
  end

  # Synchronous "Fetch latest price" button on the product detail page.
  # Blocks the request for up to ~5s while we hit the source URL.
  def fetch_price
    if @product.source_url.blank?
      return redirect_to @product, alert: "This product has no source URL to refresh."
    end

    PriceFetcher.call(@product)

    if @product.last_fetch_error.present?
      redirect_to @product, alert: "Couldn't refresh: #{@product.last_fetch_error}"
    else
      redirect_to @product, notice: "Price refreshed."
    end
  end

  private

  # Group price records by store for the price-history chart. A store with a
  # single observation gets that point duplicated at the chart's overall date
  # range so the chart still draws a flat horizontal line, same convention as
  # Newegg / CamelCamelCamel. When the product itself has only one record
  # (so all dates are the same), extend the range to today (with a 1-day
  # minimum span) so the line still has somewhere to draw.
  def build_chart_data(records)
    return [] if records.empty?

    dates = records.map { |r| r.recorded_at.to_date }
    range_start, range_end = dates.min, dates.max

    if range_start == range_end
      range_end = [ Date.current, range_start + 1 ].max
    end

    records.group_by(&:store_name).map do |store, recs|
      points = recs.sort_by(&:recorded_at).map { |r| [ r.recorded_at.to_date.iso8601, r.price.to_f ] }

      if points.size == 1
        _, y = points.first
        points = [ [ range_start.iso8601, y ], [ range_end.iso8601, y ] ]
      end

      { name: store.presence || "Unknown", data: points }
    end
  end

  # Sort options exposed on the products index page. Anything not in this
  # whitelist falls back to "newest first" so users can't inject SQL via params.
  SORT_OPTIONS = {
    "newest"     => "products.created_at DESC",
    "oldest"     => "products.created_at ASC",
    "name_asc"   => "LOWER(products.name) ASC",
    "name_desc"  => "LOWER(products.name) DESC",
    "price_asc"  => "latest_price ASC NULLS LAST",
    "price_desc" => "latest_price DESC NULLS LAST"
  }.freeze

  def sort_products(scope, key)
    order_clause = SORT_OPTIONS[key] || SORT_OPTIONS["newest"]

    if order_clause.start_with?("latest_price")
      scope
        .left_joins(:price_records)
        .select("products.*, MAX(price_records.price) AS latest_price")
        .group("products.id")
        .order(Arel.sql(order_clause))
    else
      scope.order(Arel.sql(order_clause))
    end
  end

  def fuzzy_search(scope, query)
    tokens = query.to_s.downcase.split(/\s+/).reject(&:blank?)
    return scope if tokens.empty?

    tokens.inject(scope) do |s, token|
      pattern = "%#{token}%"
      s.where(
        "LOWER(name) LIKE ? OR LOWER(category) LIKE ? OR LOWER(description) LIKE ?",
        pattern, pattern, pattern
      )
    end
  end

  def set_product
    @product = Current.user.products.find(params[:id])
  end

  # New form: source_url + category by default. When the scraper fails or the
  # user opts into manual mode, name/description/image_url are also accepted
  # so the user can finish onboarding without a working scrape.
  def create_params
    params.require(:product).permit(:category, :source_url, :name, :description, :image_url)
  end

  # Map scraper exceptions to a single user-facing sentence. We deliberately
  # don't surface raw exception text (DNS errors, "getaddrinfo(3)", HTTP codes)
  # to end users — those belong in logs, not in a flash banner.
  def friendly_scrape_error(error)
    case error
    when PriceScrapers::TransientError
      "We couldn't reach that site right now."
    when PriceScrapers::PermanentError
      "That URL didn't work — the page may not exist or the site may be blocking automated lookups."
    else
      "We couldn't read product details from that page."
    end
  end

  # Edit form keeps everything editable so users can correct scraped values.
  def update_params
    params.require(:product).permit(:name, :category, :description, :image_url, :source_url)
  end

  # Used when the page returns no schema.org "name" — gives the model
  # something readable so :name presence validation passes.
  def fallback_name_from(url)
    uri = URI.parse(url)
    last_segment = uri.path.to_s.split("/").reject(&:empty?).last
    [ uri.host.to_s.sub(/\Awww\./, ""), last_segment ].reject(&:blank?).join(" — ").presence || uri.to_s
  end
end
