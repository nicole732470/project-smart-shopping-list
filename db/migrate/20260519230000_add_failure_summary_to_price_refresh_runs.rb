class AddFailureSummaryToPriceRefreshRuns < ActiveRecord::Migration[8.1]
  def change
    add_column :price_refresh_runs, :failure_summary, :jsonb, null: false, default: {}
  end
end
