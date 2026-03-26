require "./spec_helper"

describe HTTP::CookieJar::Entry do
  it "knows if it is expired" do
    entry = HTTP::CookieJar::Entry.new(
      cookie: HTTP::Cookie.new("session_id", "abc123"),
      domain: "example.com",
      path: "/",
      expires_at: Time.utc - 1.second
    )

    entry.expired?.should be_true
  end

  it "returns a touched copy with updated access time" do
    created_at = Time.utc - 5.seconds
    entry = HTTP::CookieJar::Entry.new(
      cookie: HTTP::Cookie.new("session_id", "abc123"),
      domain: "example.com",
      path: "/",
      created_at: created_at,
      last_access_at: created_at
    )

    touched = entry.touch

    touched.last_access_at.should be > entry.last_access_at
    touched.created_at.should eq(entry.created_at)
  end
end
