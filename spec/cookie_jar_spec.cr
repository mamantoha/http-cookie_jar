require "./spec_helper"

describe HTTP::CookieJar do
  it "is empty by default" do
    jar = HTTP::CookieJar.new

    jar.to_a.should be_empty
  end

  it "adds a cookie for a URI" do
    jar = HTTP::CookieJar.new

    jar.add("https://example.com/login", HTTP::Cookie.new("session_id", "abc123"))

    cookies = jar.cookies_for("https://example.com/account")

    cookies["session_id"].value.should eq("abc123")
  end

  it "adds multiple cookies from HTTP::Cookies" do
    jar = HTTP::CookieJar.new
    cookies = HTTP::Cookies.new
    cookies << HTTP::Cookie.new("session_id", "abc123")
    cookies << HTTP::Cookie.new("theme", "dark")

    jar.add("https://example.com/login", cookies)

    stored = jar.cookies_for("https://example.com/account")

    stored["session_id"].value.should eq("abc123")
    stored["theme"].value.should eq("dark")
  end

  it "extracts cookies from Set-Cookie response headers" do
    jar = HTTP::CookieJar.new
    headers = HTTP::Headers{
      "Set-Cookie" => [
        "session_id=abc123; Path=/; HttpOnly",
        "theme=dark; Path=/",
      ],
    }

    jar.extract(headers, "https://example.com/login")

    cookies = jar.cookies_for("https://example.com/account")

    cookies["session_id"].value.should eq("abc123")
    cookies["theme"].value.should eq("dark")
  end

  it "keeps host-only cookies on the original host only" do
    jar = HTTP::CookieJar.new

    jar.add("https://example.com/login", HTTP::Cookie.new("session_id", "abc123"))

    jar.cookies_for("https://example.com/account")["session_id"].value.should eq("abc123")
    jar.cookies_for("https://api.example.com/account")["session_id"]?.should be_nil
  end

  it "returns domain cookies for matching subdomains" do
    jar = HTTP::CookieJar.new

    jar.add("https://example.com/login", HTTP::Cookie.new("session_id", "abc123", domain: "example.com"))

    jar.cookies_for("https://api.example.com/account")["session_id"].value.should eq("abc123")
  end

  it "normalizes cookie domains before matching" do
    jar = HTTP::CookieJar.new

    jar.add("https://example.com/login", HTTP::Cookie.new("session_id", "abc123", domain: ".Example.COM"))

    jar.cookies_for("https://api.example.com/account")["session_id"].value.should eq("abc123")
  end

  it "rejects domain cookies that do not match the origin host" do
    jar = HTTP::CookieJar.new

    jar.add("https://example.com/login", HTTP::Cookie.new("session_id", "abc123", domain: "other.com"))

    jar.cookies_for("https://example.com/account")["session_id"]?.should be_nil
  end

  it "rejects domain cookies for IP address hosts" do
    jar = HTTP::CookieJar.new

    jar.add("https://127.0.0.1/login", HTTP::Cookie.new("session_id", "abc123", domain: "127.0.0.1"))

    jar.cookies_for("https://127.0.0.1/account")["session_id"]?.should be_nil
  end

  it "rejects domain cookies without an embedded dot" do
    jar = HTTP::CookieJar.new

    jar.add("https://api.example.com/login", HTTP::Cookie.new("session_id", "abc123", domain: "com"))

    jar.cookies_for("https://api.example.com/account")["session_id"]?.should be_nil
  end

  it "returns cookies only for matching request paths" do
    jar = HTTP::CookieJar.new

    jar.add("https://example.com/login", HTTP::Cookie.new("session_id", "abc123", path: "/account"))

    jar.cookies_for("https://example.com/account/settings")["session_id"].value.should eq("abc123")
    jar.cookies_for("https://example.com/admin")["session_id"]?.should be_nil
  end

  it "normalizes invalid cookie paths to the default request path" do
    jar = HTTP::CookieJar.new

    jar.add("https://example.com/account/login", HTTP::Cookie.new("session_id", "abc123", path: "invalid"))

    jar.cookies_for("https://example.com/account/settings")["session_id"].value.should eq("abc123")
    jar.cookies_for("https://example.com/admin")["session_id"]?.should be_nil
  end

  it "returns matching cookies ordered by longer paths first" do
    jar = HTTP::CookieJar.new

    jar.add("https://example.com/login", HTTP::Cookie.new("root", "1", path: "/"))
    jar.add("https://example.com/login", HTTP::Cookie.new("account", "2", path: "/account"))

    headers = HTTP::Headers.new
    jar.add_cookie_header(headers, "https://example.com/account/settings")

    headers["Cookie"].should eq("account=2; root=1")
  end

  it "replaces an existing cookie with the same domain, path, and name" do
    jar = HTTP::CookieJar.new

    jar.add("https://example.com/login", HTTP::Cookie.new("session_id", "old", path: "/"))
    jar.add("https://example.com/login", HTTP::Cookie.new("session_id", "new", path: "/"))

    cookies = jar.cookies_for("https://example.com/account")

    cookies["session_id"].value.should eq("new")
    jar.to_a.size.should eq(1)
  end

  it "adds the Cookie header for a request URI" do
    jar = HTTP::CookieJar.new
    headers = HTTP::Headers.new

    jar.add("https://example.com/login", HTTP::Cookie.new("session_id", "abc123"))
    jar.add_cookie_header(headers, "https://example.com/account")

    headers["Cookie"].should eq("session_id=abc123")
  end

  it "clears matching cookies by domain, path, and name" do
    jar = HTTP::CookieJar.new

    jar.add("https://example.com/login", HTTP::Cookie.new("session_id", "abc123", path: "/"))
    jar.add("https://example.com/login", HTTP::Cookie.new("theme", "dark", path: "/"))

    jar.clear("example.com", "/", "session_id")

    cookies = jar.cookies_for("https://example.com/account")

    cookies["session_id"]?.should be_nil
    cookies["theme"].value.should eq("dark")
  end

  it "clears expired cookies" do
    jar = HTTP::CookieJar.new
    expires_at = Time.utc - 1.second

    jar.add("https://example.com/login", HTTP::Cookie.new("session_id", "abc123", expires: expires_at))
    jar.clear_expired

    jar.cookies_for("https://example.com/account").to_a.should be_empty
  end

  it "treats Max-Age as the effective expiration time" do
    jar = HTTP::CookieJar.new
    cookie = HTTP::Cookie.new("session_id", "abc123", max_age: 1.second)

    jar.add("https://example.com/login", cookie)
    jar.clear_expired(cookie.creation_time + 2.seconds)

    jar.cookies_for("https://example.com/account").to_a.should be_empty
  end

  it "does not store already expired cookies" do
    jar = HTTP::CookieJar.new
    expired_cookie = HTTP::Cookie.new("session_id", "abc123", expires: Time.utc - 1.second)

    jar.add("https://example.com/login", expired_cookie)

    jar.to_a.should be_empty
  end

  it "removes an existing cookie when a replacement is immediately expired" do
    jar = HTTP::CookieJar.new

    jar.add("https://example.com/login", HTTP::Cookie.new("session_id", "abc123", path: "/"))
    jar.add("https://example.com/login", HTTP::Cookie.new("session_id", "", path: "/", max_age: Time::Span.zero))

    jar.cookies_for("https://example.com/account")["session_id"]?.should be_nil
    jar.to_a.should be_empty
  end

  it "round-trips through JSON persistence" do
    jar = HTTP::CookieJar.new

    jar.add("https://example.com/login", HTTP::Cookie.new("session_id", "abc123", path: "/"))

    restored = HTTP::CookieJar.from_json(jar.to_json)

    restored.cookies_for("https://example.com/account")["session_id"].value.should eq("abc123")
  end
end
