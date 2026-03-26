require "http/client"
require "../src/cookiejar"

COOKIEJAR_PATH = File.expand_path("./cookies.txt", __DIR__)

client = HTTP::Client.new(URI.parse("https://www.scrapingcourse.com"))
jar = HTTP::MozillaCookieJar.new(COOKIEJAR_PATH)
jar.load if File.exists?(COOKIEJAR_PATH)

begin
  dashboard_headers = HTTP::Headers.new
  jar.add_cookie_header(dashboard_headers, "https://www.scrapingcourse.com/dashboard")

  dashboard_response = client.get("/dashboard", headers: dashboard_headers)

  if dashboard_response.success?
    puts dashboard_response.body
  else
    STDERR.puts "Dashboard request failed with status #{dashboard_response.status_code}"
  end
rescue ex
  STDERR.puts "Error: #{ex.message}"
ensure
  jar.save(include_session: true)
end
