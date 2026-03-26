module HTTP
  class DefaultCookiePolicy < CookiePolicy
    getter allowed_domains, blocked_domains, secure_protocols

    def initialize(
      @allowed_domains : Array(String)? = nil,
      @blocked_domains : Array(String) = [] of String,
      @secure_protocols : Array(String) = ["https", "wss"],
    )
    end

    def accept?(cookie : HTTP::Cookie, uri : URI) : Bool
      host = normalized_host(uri)
      return false if host.empty?

      return false if blocked?(host)
      return false unless allowed?(host)

      if domain = normalized_cookie_domain(cookie.domain)
        return false unless valid_cookie_domain?(domain)
        return false if ip_address?(host)
        return false unless domain_match?(host, domain)
      end

      true
    end

    def return?(entry : HTTP::CookieJar::Entry, uri : URI) : Bool
      host = normalized_host(uri)
      path = normalized_path(uri)
      return false if host.empty?

      return false if blocked?(host)
      return false unless allowed?(host)
      return false if entry.secure && !secure_protocol?(uri.scheme)
      return false unless domain_match?(host, entry.domain, entry.host_only)
      return false unless path_match?(path, entry.path)

      true
    end

    private def normalized_host(uri : URI) : String
      uri.host.try(&.downcase) || ""
    end

    private def normalized_path(uri : URI) : String
      uri.path.presence || "/"
    end

    private def normalized_cookie_domain(domain : String?) : String?
      domain.try(&.downcase.lstrip('.'))
    end

    private def domain_match?(host : String, domain : String, host_only : Bool = false) : Bool
      return host == domain if host_only

      host == domain || host.ends_with?(".#{domain}")
    end

    private def valid_cookie_domain?(domain : String) : Bool
      return false if domain.empty?
      return false if ip_address?(domain)

      domain.includes?('.')
    end

    private def path_match?(request_path : String, cookie_path : String) : Bool
      return true if request_path == cookie_path
      return false unless request_path.starts_with?(cookie_path)
      return true if cookie_path.ends_with?('/')

      request_path[cookie_path.size]? == '/'
    end

    private def ip_address?(host : String) : Bool
      host.matches?(/\A\d{1,3}(?:\.\d{1,3}){3}\z/)
    end

    private def allowed?(host : String?) : Bool
      return true unless domains = @allowed_domains
      return false unless host

      domains.any? { |domain| host == domain || host.ends_with?(".#{domain}") }
    end

    private def blocked?(host : String?) : Bool
      return false unless host

      @blocked_domains.any? { |domain| host == domain || host.ends_with?(".#{domain}") }
    end

    private def secure_protocol?(scheme : String?) : Bool
      return false unless scheme

      @secure_protocols.includes?(scheme)
    end
  end
end
