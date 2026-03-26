module HTTP
  class CookieJar
    struct Entry
      getter cookie, domain, path, created_at, last_access_at, expires_at
      getter host_only, persistent

      def initialize(
        @cookie : HTTP::Cookie,
        @domain : String,
        @path : String,
        @created_at : Time = Time.utc,
        last_access_at : Time? = nil,
        @expires_at : Time? = nil,
        @host_only : Bool = true,
        @persistent : Bool = false,
      )
        @last_access_at = last_access_at || @created_at
      end

      delegate name, value, secure, http_only, samesite, to: @cookie

      def expired?(now : Time = Time.utc) : Bool
        if expires_at = @expires_at
          expires_at <= now
        else
          false
        end
      end

      def touch(now : Time = Time.utc) : self
        self.class.new(
          cookie: @cookie,
          domain: @domain,
          path: @path,
          created_at: @created_at,
          last_access_at: now,
          expires_at: @expires_at,
          host_only: @host_only,
          persistent: @persistent
        )
      end

      def to_json(json : JSON::Builder) : Nil
        json.object do
          json.field "name", name
          json.field "value", value
          json.field "domain", @domain
          json.field "path", @path
          json.field "host_only", @host_only
          json.field "persistent", @persistent
          json.field "created_at", @created_at.to_unix
          json.field "last_access_at", @last_access_at.to_unix
          json.field "expires_at", @expires_at.try(&.to_unix)
          json.field "secure", secure
          json.field "http_only", http_only
          json.field "samesite", samesite.try(&.to_s)
          json.field "extension", @cookie.extension
          json.field "max_age", @cookie.max_age.try(&.total_seconds.to_i)
        end
      end

      def self.from_json(value : JSON::Any) : self
        object = value.as_h

        host_only = object["host_only"].as_bool
        domain = object["domain"].as_s
        path = object["path"].as_s
        created_at = Time.unix(object["created_at"].as_i64)
        last_access_at = Time.unix(object["last_access_at"].as_i64)
        expires_at = object["expires_at"]?.try(&.as_i64?).try { |time| Time.unix(time) }
        max_age = object["max_age"]?.try(&.as_i64?).try(&.seconds)
        samesite = object["samesite"]?.try(&.as_s?).try { |name| HTTP::Cookie::SameSite.parse(name) }

        cookie = HTTP::Cookie.new(
          object["name"].as_s,
          object["value"].as_s,
          path: path,
          expires: expires_at,
          domain: host_only ? nil : domain,
          secure: object["secure"].as_bool,
          http_only: object["http_only"].as_bool,
          samesite: samesite,
          extension: object["extension"]?.try(&.as_s?),
          max_age: max_age,
          creation_time: created_at
        )

        new(
          cookie: cookie,
          domain: domain,
          path: path,
          created_at: created_at,
          last_access_at: last_access_at,
          expires_at: expires_at,
          host_only: host_only,
          persistent: object["persistent"].as_bool
        )
      end
    end
  end
end
