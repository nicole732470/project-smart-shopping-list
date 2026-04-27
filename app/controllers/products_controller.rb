class ProductsController < ApplicationController
  before_action :set_product, only: [ :show, :edit, :update, :destroy ]

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
    @product = Current.user.products.build(product_params)
    if @product.save
      redirect_to @product, notice: "Product added successfully!"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @product.update(product_params)
      redirect_to @product, notice: "Product updated successfully!"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @product.destroy
    redirect_to products_url, notice: "Product deleted."
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

  def product_params
    params.require(:product).permit(:name, :category, :description, :image_url)
  end
end
