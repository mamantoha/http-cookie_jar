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

  it "keeps country-code domain acceptance permissive by default" do
    policy = HTTP::DefaultCookiePolicy.new
    policy.strict_domain.should be_false
    cookie = HTTP::Cookie.new("session", "value", domain: "co.uk")

    policy.accept?(cookie, URI.parse("https://attacker.co.uk/")).should be_true
  end

  it "rejects common country-code second-level domains in strict mode" do
    policy = HTTP::DefaultCookiePolicy.new(strict_domain: true)
    policy.strict_domain.should be_true
    %w[co ac com edu org net gov mil int aero biz cat coop info jobs mobi museum name pro travel eu].each do |label|
      domain = "#{label}.uk"
      cookie = HTTP::Cookie.new("session", "value", domain: domain)

      policy.accept?(cookie, URI.parse("https://attacker.#{domain}/")).should be_false
    end
    [".Co.UK", "gov.uk", "co.nz"].each do |domain|
      cookie = HTTP::Cookie.new("session", "value", domain: domain)
      host = domain.downcase.lstrip('.')

      policy.accept?(cookie, URI.parse("https://attacker.#{host}/")).should be_false
      policy.accept?(cookie, URI.parse("https://#{host}/")).should be_false
    end
  end

  it "limits strict mode to the country-code heuristic" do
    policy = HTTP::DefaultCookiePolicy.new(strict_domain: true)
    ["example.co.uk", ".Example.COM", "github.io", "a.ck", "foo.kawasaki.jp", "co.example"].each do |domain|
      cookie = HTTP::Cookie.new("session", "value", domain: domain)
      host = domain.downcase.lstrip('.')

      policy.accept?(cookie, URI.parse("https://app.#{host}/")).should be_true
    end
  end
end
