require "httparty"
require "nokogiri"
require "bigdecimal"

module PriceScrapers
  # Abstract base for site adapters. Subclasses implement #parse(doc, url),
  # returning a Result. Base handles HTTP, common headers, and parsing helpers.
  class Base
    DEFAULT_USER_AGENT =
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 " \
      "(KHTML, like Gecko) Version/17.0 Safari/605.1.15"

    # Subclasses can override to use a more realistic UA per site.
    def user_agent
      DEFAULT_USER_AGENT
    end

    # Public entry point used by the facade. Adapters override #parse only.
    def fetch(url, timeout: 5)
      response = http_get(url, timeout: timeout)
      doc      = Nokogiri::HTML(response.body)
      result   = parse(doc, url)
      result.store_name ||= store_name_from_host(url)
      result
    end

    # Subclasses must implement.
    def parse(_doc, _url)
      raise NotImplementedError
    end

    private

    def http_get(url, timeout:)
      response = HTTParty.get(
        url,
        timeout: timeout,
        follow_redirects: true,
        headers: {
          "User-Agent"      => user_agent,
          "Accept"          => "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
          "Accept-Language" => "en-US,en;q=0.9",
        }
      )
      if response.code >= 500
        raise TransientError, "HTTP #{response.code} from #{URI.parse(url).host}"
      elsif response.code >= 400
        raise PermanentError, "HTTP #{response.code} from #{URI.parse(url).host}"
      end
      response
    rescue Net::OpenTimeout, Net::ReadTimeout, HTTParty::Error => e
      raise TransientError, "#{e.class}: #{e.message}"
    rescue SocketError => e
      raise PermanentError, "Cannot resolve host: #{e.message}"
    end

    # "$1,234.56" / "USD 1234.56" / "1.234,56" -> BigDecimal
    # Returns nil if the input is blank or cannot be cleaned.
    def parse_price(raw)
      return nil if raw.blank?
      str = raw.to_s.strip
      cleaned = str.gsub(/[^\d.,-]/, "")
      return nil if cleaned.empty?
      # If both '.' and ',' appear, assume the rightmost one is the decimal.
      if cleaned.count(".") > 0 && cleaned.count(",") > 0
        if cleaned.rindex(".") > cleaned.rindex(",")
          cleaned = cleaned.delete(",")
        else
          cleaned = cleaned.delete(".").tr(",", ".")
        end
      elsif cleaned.count(",") > 1
        cleaned = cleaned.delete(",")
      elsif cleaned.count(",") == 1 && cleaned.count(".") == 0
        # Treat "1,99" as 1.99 (Euro-ish), but "1,234" as 1234. Heuristic:
        # if there are exactly 3 digits after the comma, treat as thousands sep.
        post = cleaned.split(",").last
        cleaned = post.length == 3 ? cleaned.delete(",") : cleaned.tr(",", ".")
      end
      BigDecimal(cleaned)
    rescue ArgumentError
      nil
    end

    # Common subdomain prefixes that aren't the brand name. Strip these to
    # turn "shop.lululemon.com" -> "Lululemon" instead of "Shop".
    HOST_PREFIX = /\A(www|shop|store|m|mobile|us|en|en-us)\./i

    def store_name_from_host(url)
      host  = URI.parse(url).host.to_s.downcase.sub(HOST_PREFIX, "")
      label = host.split(".").first
      label&.capitalize.presence || host
    end
  end
end
