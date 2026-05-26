module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
    helper_method :authenticated?
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end
  end

  private
    def authenticated?
      resume_session
    end

    def require_authentication
      resume_session || request_authentication
    end

    def resume_session
      Current.session ||= find_session_by_cookie
    end

    def find_session_by_cookie
      return unless cookies.signed[:session_id]

      session = Session.find_by(id: cookies.signed[:session_id])
      return unless session

      if session.expired?
        session.destroy
        cookies.delete(:session_id)
        return
      end

      session
    end

    def request_authentication
      session[:return_to_after_authenticating] = request.url
      redirect_to new_session_path
    end

    def after_authentication_url
      return_to = session.delete(:return_to_after_authenticating)
      safe_authentication_redirect_url(return_to) || root_url
    end

    # Only send users to a post-login URL they can actually load. Stale
    # return_to values — e.g. a product page they don't own, or an /auth/*
    # path — otherwise produce a confusing 404 right after Google sign-in
    # even though the session was created successfully.
    def safe_authentication_redirect_url(url)
      return nil if url.blank?

      uri = URI.parse(url)
      return nil if uri.host.present? && uri.host != request.host

      path = uri.path.to_s
      return nil if auth_related_path?(path)
      return nil unless authenticated_resource_path?(path)

      uri.query.present? ? "#{path}?#{uri.query}" : path
    rescue URI::InvalidURIError
      nil
    end

    def auth_related_path?(path)
      path.start_with?("/auth/", "/session", "/registration", "/passwords")
    end

    def authenticated_resource_path?(path)
      user = Current.user
      return true unless user

      if (match = path.match(%r{\A/products/(\d+)(?:/|\z)}))
        return user.products.exists?(match[1])
      end

      if (match = path.match(%r{\A/price_records/(\d+)(?:/|\z)}))
        return PriceRecord.where(product: user.products).exists?(match[1])
      end

      true
    end

    def start_new_session_for(user)
      user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip).tap do |session|
        Current.session = session
        cookies.signed[:session_id] = {
          value: session.id,
          httponly: true,
          same_site: :lax,
          expires: session.expires_at
        }
      end
    end

    def terminate_session
      Current.session&.destroy
      cookies.delete(:session_id)
    end
end
