require "http/client"
require "../src/cookiejar"

# https://scrape.do/blog/web-scraping-cookies/

COOKIEJAR_PATH = File.expand_path("./cookies.txt", __DIR__)

client = HTTP::Client.new(URI.parse("https://www.scrapingcourse.com"))
jar = HTTP::MozillaCookieJar.new(COOKIEJAR_PATH)

begin
  # Perform login.
  login_headers = HTTP::Headers{"Content-Type" => "application/x-www-form-urlencoded"}
  jar.add_cookie_header(login_headers, "https://www.scrapingcourse.com/login")

  login_body = URI::Params.encode({
    "email"    => "admin@example.com",
    "password" => "password",
  })

  login_response = client.post("/login", headers: login_headers, body: login_body)
  jar.extract(login_response.headers, "https://www.scrapingcourse.com/login")

  jar.save(include_session: true)

  puts "Logged in successfully"
  puts "Persisted cookie jar to #{COOKIEJAR_PATH}"
  pp jar.to_a

  # Fetch dashboard content with the stored cookies.
  dashboard_headers = HTTP::Headers.new
  jar.add_cookie_header(dashboard_headers, "https://www.scrapingcourse.com/dashboard")

  dashboard_response = client.get("/dashboard", headers: dashboard_headers)
  puts dashboard_response.body
rescue ex
  STDERR.puts "Error: #{ex.message}"
end
