class AssistantController < ApplicationController
  def index
    @query = params[:q].to_s.strip
    @products = Current.user.products.includes(:price_records)

    if @query.present?
      # AiAssistant always returns an Answer struct (AI when available,
      # keyword-match heuristic otherwise). The view renders the same UI
      # in either case, with a small source badge so the user can tell.
      @answer = AiAssistant.call(query: @query, products: @products.to_a)
      @example_questions = []
    else
      @answer = nil
      @example_questions = [
        "Show me the best deals on my watchlist right now",
        "Anything under $100 worth picking up?",
        "Which products have dropped to their lowest ever?",
        "Suggest a gift under $50",
        "What's a good electronics buy this week?"
      ]
    end
  end
end
