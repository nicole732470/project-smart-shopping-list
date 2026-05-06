class BudgetPlannerController < ApplicationController
  def index
    @budget = params[:budget].presence&.to_f

    all = Current.user.products
      .joins(:price_records)
      .select("products.*, MIN(price_records.price) AS lowest_price_seen")
      .group("products.id")
      .order(Arel.sql("lowest_price_seen ASC"))

    if @budget&.positive?
      @affordable  = all.having("MIN(price_records.price) <= ?", @budget)
      @over_budget = all.having("MIN(price_records.price) > ?",  @budget)
      @total_if_all = @affordable.sum { |p| p.lowest_price_seen.to_f }
      @remaining    = @budget - @total_if_all
    end
  end
end
