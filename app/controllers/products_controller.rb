class ProductsController < ApplicationController
  before_action :set_product, only: [ :show, :edit, :update, :destroy, :fetch_price ]

  def index
    @products = Current.user.products.includes(:price_records)
    @products = fuzzy_search(@products, params[:search]) if params[:search].present?
  end

  def show
    @price_records = @product.price_records.order(recorded_at: :desc)
  end

  def new
    @product = Current.user.products.build
  end

  def create
    @product = Current.user.products.build(create_params)

    if @product.source_url.blank?
      @product.errors.add(:source_url, "can't be blank")
      return render :new, status: :unprocessable_entity
    end

    begin
      result = PriceScrapers.fetch(@product.source_url, timeout: 5)
    rescue PriceScrapers::Error => e
      flash.now[:alert] = "Couldn't read that URL: #{e.message}. Try a different link."
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

  # New form: only source_url + category. name/image/description are populated
  # by the scraper in #create, never from user input.
  def create_params
    params.require(:product).permit(:category, :source_url)
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
