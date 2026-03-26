require "./spec_helper"

describe HTTP::MozillaCookieJar do
  it "saves and loads persistent cookies in netscape format" do
    dir = Dir.tempdir
    begin
      path = File.join(dir, "cookies.txt")
      jar = HTTP::MozillaCookieJar.new(path)

      jar.add("https://example.com/login", HTTP::Cookie.new("session_id", "abc123", path: "/", expires: Time.utc + 1.day))
      jar.save

      restored = HTTP::MozillaCookieJar.new(path)
      restored.load

      restored.cookies_for("https://example.com/account")["session_id"].value.should eq("abc123")
    ensure
      FileUtils.rm_rf(dir)
    end
  end

  it "skips session cookies by default when saving" do
    dir = Dir.tempdir
    begin
      path = File.join(dir, "cookies.txt")
      jar = HTTP::MozillaCookieJar.new(path)

      jar.add("https://example.com/login", HTTP::Cookie.new("session_id", "abc123", path: "/"))
      jar.save

      restored = HTTP::MozillaCookieJar.new(path)
      restored.load

      restored.cookies_for("https://example.com/account")["session_id"]?.should be_nil
    ensure
      FileUtils.rm_rf(dir)
    end
  end

  it "can save session cookies when requested" do
    dir = Dir.tempdir
    begin
      path = File.join(dir, "cookies.txt")
      jar = HTTP::MozillaCookieJar.new(path)

      jar.add("https://example.com/login", HTTP::Cookie.new("session_id", "abc123", path: "/"))
      jar.save(include_session: true)

      restored = HTTP::MozillaCookieJar.new(path)
      restored.load

      restored.cookies_for("https://example.com/account")["session_id"].value.should eq("abc123")
    ensure
      FileUtils.rm_rf(dir)
    end
  end

  it "supports the #HttpOnly_ domain prefix" do
    dir = Dir.tempdir
    begin
      path = File.join(dir, "cookies.txt")

      File.write(
        path,
        "# Netscape HTTP Cookie File\n" \
        "#HttpOnly_.example.com\tTRUE\t/\tFALSE\t#{(Time.utc + 1.day).to_unix}\tsession_id\tabc123\n"
      )

      jar = HTTP::MozillaCookieJar.new(path)
      jar.load

      entry = jar.to_a.first
      entry.http_only.should be_true
      jar.cookies_for("https://api.example.com/account")["session_id"].value.should eq("abc123")
    ensure
      FileUtils.rm_rf(dir)
    end
  end

  it "ignores comments and blank lines" do
    dir = Dir.tempdir
    begin
      path = File.join(dir, "cookies.txt")

      File.write(
        path,
        "# Netscape HTTP Cookie File\n\n" \
        "# comment\n" \
        ".example.com\tTRUE\t/\tFALSE\t#{(Time.utc + 1.day).to_unix}\tsession_id\tabc123\n"
      )

      jar = HTTP::MozillaCookieJar.new(path)
      jar.load

      jar.cookies_for("https://api.example.com/account")["session_id"].value.should eq("abc123")
    ensure
      FileUtils.rm_rf(dir)
    end
  end
end
