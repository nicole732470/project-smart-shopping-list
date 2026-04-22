class PriceRecordsController < ApplicationController
  before_action :set_price_record, only: [ :show, :edit, :update, :destroy ]

  def index
    @price_records = PriceRecord.where(product: Current.user.products).includes(:product).order(recorded_at: :desc)
  end

  def show; end

  def new
    @product = Current.user.products.find(params[:product_id])
    @price_record = @product.price_records.new
  end

  def create
    @product = Current.user.products.find(params[:product_id])
    @price_record = @product.price_records.new(price_record_params)
    @price_record.recorded_at ||= Time.current
    if @price_record.save
      redirect_to @product, notice: "Price record added successfully!"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @product = @price_record.product
  end

  def update
    if @price_record.update(price_record_params)
      redirect_to @price_record, notice: "Price record updated successfully!"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    product = @price_record.product
    @price_record.destroy
    redirect_to product, notice: "Price record deleted."
  end

  private

  def set_price_record
    @price_record = PriceRecord.where(product: Current.user.products).find(params[:id])
  end

  def price_record_params
    params.require(:price_record).permit(:price, :store_name, :url, :recorded_at, :notes)
  end
end
