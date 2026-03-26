# HTTP::CookieJar

[![Crystal CI](https://github.com/mamantoha/http-cookie_jar/actions/workflows/crystal.yml/badge.svg)](https://github.com/mamantoha/http-cookie_jar/actions/workflows/crystal.yml)
[![GitHub release](https://img.shields.io/github/release/mamantoha/http-cookie_jar.svg)](https://github.com/mamantoha/http-cookie_jar/releases)
[![License](https://img.shields.io/github/license/mamantoha/http-cookie_jar.svg)](https://github.com/mamantoha/http-cookie_jar/blob/main/LICENSE)

Standalone HTTP cookie jar for Crystal stdlib HTTP types.

`HTTP::CookieJar` builds on top of:

- `HTTP::Cookie`
- `HTTP::Cookies`
- `HTTP::Headers`
- `URI`

## Status

This shard is usable today, but still early-stage.

It already covers the main workflow needed by real HTTP clients:

- extract cookies from responses
- store them in memory
- return matching cookies for later requests
- generate request `Cookie` headers

It does not yet aim for full feature parity with Python's `http.cookiejar` or
complete RFC 6265 edge-case coverage.

Current functionality:

- in-memory cookie storage
- add single cookies or `HTTP::Cookies`
- extract cookies from `Set-Cookie` response headers
- return cookies for a request URI
- add the `Cookie` header to request headers
- RFC-oriented domain matching
- RFC-oriented path matching
- host-only and domain cookie distinction
- replacement by cookie name/domain/path
- ordered cookie return by path specificity
- clear all cookies
- clear cookies by domain/path/name
- clear expired cookies
- `Max-Age` aware expiration handling
- immediate removal of expired replacement cookies
- JSON persistence
- file-backed cookie jars
- Mozilla / Netscape `cookies.txt` persistence
- domain normalization
- RFC-style cookie path normalization and defaulting
- host validation during acceptance and return
- configurable cookie policy

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  cookie_jar:
    github: mamantoha/http-cookie_jar
```

Then require it:

```crystal
require "cookie_jar"
```

## Usage

### Create a jar

```crystal
require "cookie_jar"

jar = HTTP::CookieJar.new
```

### Add cookies

```crystal
jar.add(
  "https://example.com/login",
  HTTP::Cookie.new("session_id", "abc123")
)

jar.add(
  "https://example.com/login",
  HTTP::Cookie.new("theme", "dark", path: "/", secure: true)
)
```

### Add multiple cookies

```crystal
cookies = HTTP::Cookies.new
cookies << HTTP::Cookie.new("session_id", "abc123")
cookies << HTTP::Cookie.new("theme", "dark")

jar.add("https://example.com/login", cookies)
```

### Extract cookies from response headers

```crystal
headers = HTTP::Headers{
  "Set-Cookie" => [
    "session_id=abc123; Path=/; HttpOnly",
    "theme=dark; Path=/",
  ],
}

jar.extract(headers, "https://example.com/login")
```

### Return cookies for a request URI

```crystal
cookies = jar.cookies_for("https://example.com/account")

cookies["session_id"].value
# => "abc123"
```

### Domain and path matching

```crystal
jar.add(
  "https://example.com/login",
  HTTP::Cookie.new("session_id", "abc123", domain: "example.com", path: "/account")
)

jar.cookies_for("https://api.example.com/account/settings")["session_id"].value
# => "abc123"

jar.cookies_for("https://api.example.com/admin")["session_id"]?
# => nil
```

Cookies are returned in a stable order, with more specific paths first.

### Add the Cookie header to request headers

```crystal
headers = HTTP::Headers.new

jar.add_cookie_header(headers, "https://example.com/account")

headers["Cookie"]?
# => "session_id=abc123; theme=dark"
```

### Use with `HTTP::Client`

```crystal
client = HTTP::Client.new(URI.parse("https://example.com"))
jar = HTTP::CookieJar.new

login_headers = HTTP::Headers.new
jar.add_cookie_header(login_headers, "https://example.com/login")

login_response = client.post("/login", headers: login_headers, body: "user=john&password=secret")
jar.extract(login_response.headers, "https://example.com/login")

account_headers = HTTP::Headers.new
jar.add_cookie_header(account_headers, "https://example.com/account")

account_response = client.get("/account", headers: account_headers)
```

### Use with `HTTP::Client` request hooks

```crystal
client = HTTP::Client.new(URI.parse("https://example.com"))
jar = HTTP::CookieJar.new

client.before_request do |request|
  uri = URI.parse("https://example.com#{request.resource}")
  jar.add_cookie_header(request.headers, uri)
end

response = client.get("/login")
jar.extract(response.headers, "https://example.com/login")
```

This pattern lets the jar stay independent while still fitting naturally into a
stateful client workflow.

### Clear cookies

```crystal
jar.clear

jar.clear("example.com")
jar.clear("example.com", "/")
jar.clear("example.com", "/", "session_id")

jar.clear_expired
```

### Replacement and deletion semantics

```crystal
jar.add("https://example.com", HTTP::Cookie.new("session_id", "old", path: "/"))
jar.add("https://example.com", HTTP::Cookie.new("session_id", "new", path: "/"))

jar.cookies_for("https://example.com/account")["session_id"].value
# => "new"

jar.add(
  "https://example.com",
  HTTP::Cookie.new("session_id", "", path: "/", max_age: Time::Span.zero)
)

jar.cookies_for("https://example.com/account")["session_id"]?
# => nil
```

### Persist the jar to disk

```crystal
jar = HTTP::MozillaCookieJar.new("cookies.txt")

jar.extract(login_response.headers, "https://example.com/login")
jar.save(include_session: true)

restored = HTTP::MozillaCookieJar.new("cookies.txt")
restored.load
restored.cookies_for("https://example.com/account")
```

Use `include_session: true` when you want to persist session cookies for later
reuse.

### JSON persistence

```crystal
File.write("cookiejar.json", jar.to_json)

restored = HTTP::CookieJar.from_json(File.read("cookiejar.json"))
restored.cookies_for("https://example.com/account")
```

### Use a Mozilla / Netscape cookie jar

```crystal
jar = HTTP::MozillaCookieJar.new("cookies.txt")

jar.add(
  "https://example.com/login",
  HTTP::Cookie.new("session_id", "abc123", path: "/", expires: Time.utc + 1.day)
)

jar.save
jar.load
```

This format is compatible with the classic Netscape `cookies.txt` layout used
by tools such as `curl`.

## Policy

`HTTP::CookieJar` accepts a policy object.

The default policy is `HTTP::DefaultCookiePolicy`.

```crystal
policy = HTTP::DefaultCookiePolicy.new(
  allowed_domains: ["example.com"],
  blocked_domains: ["tracker.example"],
)

jar = HTTP::CookieJar.new(policy: policy)
```

Current policy behavior:

- optional domain allow-list
- optional domain block-list
- host-only cookies only return to the original host
- domain cookies may return to matching subdomains
- domain cookies are rejected for IP hosts
- low-quality domain attributes such as `com` are rejected
- path matching is enforced for returned cookies
- secure cookies are only returned for secure schemes
- empty request hosts are rejected

## API

Main types:

- `HTTP::CookieJar`
- `HTTP::CookieJar::Entry`
- `HTTP::CookiePolicy`
- `HTTP::DefaultCookiePolicy`
- `HTTP::FileCookieJar`
- `HTTP::MozillaCookieJar`

Main methods:

- `HTTP::CookieJar#add`
- `HTTP::CookieJar#extract`
- `HTTP::CookieJar#cookies_for`
- `HTTP::CookieJar#add_cookie_header`
- `HTTP::CookieJar#clear`
- `HTTP::CookieJar#clear_expired`
- `HTTP::CookieJar#to_json`
- `HTTP::CookieJar.from_json`
- `HTTP::FileCookieJar#save`
- `HTTP::FileCookieJar#load`

## Samples

- [samples/httpbin.cr](/samples/httpbin.cr)
  simple cookie round-trip with `HTTP::Client`
- [samples/login_and_dashboard.cr](samples/login_and_dashboard.cr)
  login flow with later authenticated request
- [samples/persisted_dashboard_session.cr](/samples/persisted_dashboard_session.cr)
  reuse a persisted cookie jar without sending login credentials again

## Development

Run the specs from the shard root:

```bash
crystal spec
```

## Contributors

- [mamantoha](https://github.com/mamantoha) Anton Maminov - creator, maintainer

## License

Copyright: 2026 Anton Maminov (anton.maminov@gmail.com)

This library is distributed under the MIT license. Please see the LICENSE file.
