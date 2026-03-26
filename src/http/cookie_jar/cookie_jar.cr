module HTTP
  class CookieJar
    include Enumerable(HTTP::CookieJar::Entry)

    getter policy

    def initialize(@policy : HTTP::CookiePolicy = HTTP::DefaultCookiePolicy.new)
      @store = {} of Tuple(String, String, String) => Entry
    end

    def add(uri : URI | String, cookie : HTTP::Cookie) : self
      normalized_uri = URIUtils.normalize(uri)
      entry = build_entry(cookie, normalized_uri)
      key = key_for(entry)

      return self unless policy.accept?(cookie, normalized_uri)

      if entry.expired?
        @store.delete(key)
        return self
      end

      @store[key] = entry
      self
    end

    def add(uri : URI | String, cookies : HTTP::Cookies) : self
      cookies.each do |cookie|
        add(uri, cookie)
      end

      self
    end

    def extract(headers : HTTP::Headers, uri : URI | String) : self
      add(uri, HTTP::Cookies.from_server_headers(headers))
    end

    def cookies_for(uri : URI | String) : HTTP::Cookies
      normalized_uri = URIUtils.normalize(uri)
      cookies = HTTP::Cookies.new

      applicable_entries(normalized_uri).each do |entry|
        cookies << HTTP::Cookie.new(entry.name, entry.value)
      end

      cookies
    end

    def add_cookie_header(headers : HTTP::Headers, uri : URI | String) : HTTP::Headers
      cookies = cookies_for(uri)
      cookies.add_request_headers(headers)
      headers
    end

    def clear : Nil
      @store.clear
    end

    def clear(domain : String, path : String? = nil, name : String? = nil) : Nil
      @store.reject! do |(cookie_domain, cookie_path, cookie_name), _|
        next false unless cookie_domain == domain
        next false if path && cookie_path != path
        next false if name && cookie_name != name

        true
      end
    end

    def clear_expired(now : Time = Time.utc) : Nil
      @store.reject! { |_, entry| entry.expired?(now) }
    end

    def each(& : Entry ->) : Nil
      @store.each_value do |entry|
        yield entry
      end
    end

    private def applicable_entries(uri : URI) : Array(Entry)
      @store.each_value.compact_map do |entry|
        next if entry.expired?
        next unless policy.return?(entry, uri)

        entry
      end.to_a.sort_by { |entry| {-entry.path.bytesize, entry.created_at} }
    end

    protected def add_entry(entry : Entry) : Nil
      @store[key_for(entry)] = entry
    end

    private def build_entry(cookie : HTTP::Cookie, uri : URI) : Entry
      expires_at =
        if max_age = cookie.max_age
          cookie.creation_time + max_age
        else
          cookie.expires
        end

      Entry.new(
        cookie: cookie,
        domain: normalized_domain(cookie.domain || uri.host || ""),
        path: URIUtils.normalize_cookie_path(cookie.path, uri),
        expires_at: expires_at,
        host_only: cookie.domain.nil?,
        persistent: !expires_at.nil?
      )
    end

    private def normalized_domain(domain : String) : String
      domain.downcase.lstrip('.')
    end

    private def key_for(entry : Entry) : Tuple(String, String, String)
      {entry.domain, entry.path, entry.name}
    end
  end
end
