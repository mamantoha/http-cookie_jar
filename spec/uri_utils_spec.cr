require "./spec_helper"

describe HTTP::CookieJar::URIUtils do
  it "normalizes string URIs" do
    uri = HTTP::CookieJar::URIUtils.normalize("https://example.com/login")

    uri.should be_a(URI)
    uri.host.should eq("example.com")
  end

  it "uses slash as the default path for root requests" do
    uri = URI.parse("https://example.com/")

    HTTP::CookieJar::URIUtils.default_path(uri).should eq("/")
  end

  it "uses the parent path for nested requests" do
    uri = URI.parse("https://example.com/account/login")

    HTTP::CookieJar::URIUtils.default_path(uri).should eq("/account")
  end

  it "normalizes invalid cookie paths to the default path" do
    uri = URI.parse("https://example.com/account/login")

    HTTP::CookieJar::URIUtils.normalize_cookie_path("account", uri).should eq("/account")
  end

  it "keeps valid cookie paths unchanged" do
    uri = URI.parse("https://example.com/account/login")

    HTTP::CookieJar::URIUtils.normalize_cookie_path("/account", uri).should eq("/account")
  end
end
