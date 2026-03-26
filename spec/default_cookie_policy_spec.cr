require "./spec_helper"

describe HTTP::DefaultCookiePolicy do
  it "accepts cookies by default" do
    policy = HTTP::DefaultCookiePolicy.new
    cookie = HTTP::Cookie.new("session_id", "abc123")

    policy.accept?(cookie, URI.parse("https://example.com")).should be_true
  end

  it "rejects blocked domains" do
    policy = HTTP::DefaultCookiePolicy.new(blocked_domains: ["example.com"])
    cookie = HTTP::Cookie.new("session_id", "abc123")

    policy.accept?(cookie, URI.parse("https://example.com")).should be_false
  end

  it "accepts allowed domains and subdomains" do
    policy = HTTP::DefaultCookiePolicy.new(allowed_domains: ["example.com"])
    cookie = HTTP::Cookie.new("session_id", "abc123")

    policy.accept?(cookie, URI.parse("https://api.example.com")).should be_true
  end

  it "rejects domains outside the allow list" do
    policy = HTTP::DefaultCookiePolicy.new(allowed_domains: ["example.com"])
    cookie = HTTP::Cookie.new("session_id", "abc123")

    policy.accept?(cookie, URI.parse("https://other.com")).should be_false
  end

  it "does not return secure cookies for insecure schemes" do
    policy = HTTP::DefaultCookiePolicy.new
    entry = HTTP::CookieJar::Entry.new(
      cookie: HTTP::Cookie.new("session_id", "abc123", secure: true),
      domain: "example.com",
      path: "/"
    )

    policy.return?(entry, URI.parse("http://example.com")).should be_false
    policy.return?(entry, URI.parse("https://example.com")).should be_true
  end
end
