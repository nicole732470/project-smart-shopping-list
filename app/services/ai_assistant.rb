require "net/http"
require "json"

# Free-text shopping assistant. Takes a natural-language question from the
# user ("what should I buy under $200?", "show me good headphone deals",
# "anything dropped recently?") plus a snapshot of their watchlist and asks
# an LLM via OpenRouter to surface 3 specific picks from that watchlist
# with one-line reasoning each.
#
# Graceful degradation: if the AI key is missing, AI is disabled, the
# request fails, or the response is unparseable, we fall back to keyword
# matching against product names + categories so the user still gets a
# useful answer. The view always renders an Answer struct.
class AiAssistant
  Pick   = Data.define(:product, :reason)
  Answer = Data.define(:summary, :picks, :source)

  ENDPOINT      = "https://openrouter.ai/api/v1/chat/completions"
  DEFAULT_MODEL = "google/gemma-4-26b-a4b-it:free"
  MAX_PICKS     = 3
  MAX_CANDIDATES_FOR_PROMPT = 30

  def self.call(query:, products:)
    new(query: query, products: products).call
  end

  def initialize(query:, products:)
    @query    = query.to_s.strip
    @products = Array(products)
  end

  def call
    return empty_answer if @query.blank?
    return empty_answer if @products.empty?

    return heuristic_answer unless ai_enabled?

    ai_answer
  rescue StandardError => e
    Rails.logger.info("[AiAssistant] Falling back to heuristic: #{e.class}: #{e.message}")
    heuristic_answer
  end

  private

  def ai_enabled?
    return false if ENV["OPENROUTER_API_KEY"].blank?

    flag = ENV["ENABLE_AI_DEAL_ADVICE"]
    flag.blank? || ActiveModel::Type::Boolean.new.cast(flag)
  end

  def model
    ENV["OPENROUTER_MODEL"].presence || DEFAULT_MODEL
  end

  def empty_answer
    Answer.new(summary: nil, picks: [], source: "empty")
  end

  def candidates
    @candidates ||= @products.first(MAX_CANDIDATES_FOR_PROMPT).filter_map do |product|
      latest = product.latest_price
      lowest = product.lowest_price
      next if latest.nil?

      {
        product: product,
        name: product.name,
        category: product.category,
        latest: latest.to_f,
        lowest: lowest.to_f,
        target: product.target_price&.to_f
      }
    end
  end

  def ai_answer
    uri = URI(ENDPOINT)
    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{ENV.fetch('OPENROUTER_API_KEY')}"
    request["Content-Type"]  = "application/json"
    request["HTTP-Referer"]  = ENV.fetch("APP_URL", "https://smart-shoppinglist-6ae31171e85c.herokuapp.com")
    request["X-Title"]       = "PriceTracker"
    request.body = {
      model: model,
      messages: [ { role: "user", content: prompt } ],
      max_tokens: 320,
      temperature: 0.3
    }.to_json

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, open_timeout: 3, read_timeout: 12) do |http|
      http.request(request)
    end

    raise "OpenRouter request failed with HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    text = JSON.parse(response.body).dig("choices", 0, "message", "content").to_s.strip
    raise "OpenRouter response did not include text" if text.blank?

    parsed = parse(text)
    raise "No matchable picks in AI response" if parsed.picks.empty?

    parsed
  end

  def prompt
    lines = candidates.map do |c|
      target_part = c[:target] ? ", target $#{format('%.2f', c[:target])}" : ""
      "- \"#{c[:name]}\" (#{c[:category]}): latest $#{format('%.2f', c[:latest])}, lowest ever $#{format('%.2f', c[:lowest])}#{target_part}"
    end

    <<~PROMPT
      You are a shopping assistant. Answer the user's question using ONLY the products in their watchlist below. Pick the #{MAX_PICKS} most relevant products and explain why each fits the question.

      User question:
      "#{@query}"

      Watchlist:
      #{lines.join("\n")}

      Reply in this EXACT format, no extra commentary outside the structure:
      SUMMARY: <one sentence answering the question at a high level>
      PICK: <product name copied verbatim from the watchlist> | <one short sentence citing real numbers from that product>
      PICK: <product name> | <reason>
      PICK: <product name> | <reason>

      If the question can't be reasonably answered from the watchlist, return a SUMMARY line that says so and no PICK lines. Never invent products.
    PROMPT
  end

  def parse(text)
    by_name = candidates.index_by { |c| c[:name] }

    summary_line = text[/SUMMARY:\s*(.+)/i, 1]&.strip&.gsub(/\s+/, " ")
    picks = text.scan(/^PICK:\s*(.+?)\s*\|\s*(.+)$/).filter_map do |name, reason|
      candidate = by_name[name.strip]
      next unless candidate

      Pick.new(product: candidate[:product], reason: reason.strip.gsub(/\s+/, " "))
    end.first(MAX_PICKS)

    Answer.new(summary: summary_line, picks: picks, source: "ai")
  end

  # Naive keyword overlap between the query and each product's name +
  # category. Returns the top MAX_PICKS by overlap; if nothing matches,
  # returns the candidates with the biggest savings from peak so the
  # user still sees *something* useful.
  def heuristic_answer
    keywords = @query.downcase.scan(/[a-z0-9$]+/).reject { |w| w.length < 3 || STOPWORDS.include?(w) }
    keyword_set = keywords.to_set

    scored = candidates.map do |c|
      haystack = "#{c[:name]} #{c[:category]}".downcase
      score = keyword_set.count { |k| haystack.include?(k) }
      [ score, c ]
    end

    top = scored.select { |s, _| s.positive? }.sort_by { |s, c| [ -s, c[:latest] ] }.first(MAX_PICKS).map(&:last)

    if top.empty?
      top = candidates.sort_by { |c| c[:latest] }.first(MAX_PICKS)
      summary = "I couldn't directly match your question, so here are the lowest-priced products on your watchlist:"
    else
      summary = "Top #{top.size} #{'match'.pluralize(top.size)} from your watchlist:"
    end

    picks = top.map do |c|
      reason =
        if c[:target] && c[:latest] <= c[:target]
          "Latest $#{format('%.2f', c[:latest])} is at or below your target of $#{format('%.2f', c[:target])}."
        elsif c[:latest] <= c[:lowest] + 0.01
          "Latest $#{format('%.2f', c[:latest])} matches the lowest you've ever seen."
        else
          "Latest $#{format('%.2f', c[:latest])}; lowest recorded $#{format('%.2f', c[:lowest])}."
        end

      Pick.new(product: c[:product], reason: reason)
    end

    Answer.new(summary: summary, picks: picks, source: "local")
  end

  STOPWORDS = %w[
    the and any can you what show give find tell help with this that have for any
    some are best good great cheap cheapest worth recently under over from about
    please now buy item items product products thing things which when where why
  ].to_set
end
