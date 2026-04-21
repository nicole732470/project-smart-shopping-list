class MakeProductsUserRequired < ActiveRecord::Migration[8.1]
  def up
    execute "DELETE FROM price_records WHERE product_id IN (SELECT id FROM products WHERE user_id IS NULL)"
    execute "DELETE FROM products WHERE user_id IS NULL"
    change_column_null :products, :user_id, false
  end

  def down
    change_column_null :products, :user_id, true
  end
end
