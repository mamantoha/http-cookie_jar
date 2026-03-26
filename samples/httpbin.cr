require "http/client"
require "../src/cookiejar"

client = HTTP::Client.new(URI.parse("http://httpbin.org"))
jar = HTTP::CookieJar.new

# The first GET request receives a "sessioncookie" from httpbin.org.
set_headers = HTTP::Headers.new
jar.add_cookie_header(set_headers, "http://httpbin.org/cookies/set/sessioncookie/123456789")

set_response = client.get("/cookies/set/sessioncookie/123456789", headers: set_headers)
jar.extract(set_response.headers, "http://httpbin.org/cookies/set/sessioncookie/123456789")

# The second GET request automatically sends the received cookie back.
cookie_headers = HTTP::Headers.new
jar.add_cookie_header(cookie_headers, "http://httpbin.org/cookies")

response = client.get("/cookies", headers: cookie_headers)

# Print the response body to confirm the cookie was received by the server.
puts response.body
