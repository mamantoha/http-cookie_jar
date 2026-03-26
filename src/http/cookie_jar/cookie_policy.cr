module HTTP
  abstract class CookiePolicy
    abstract def accept?(cookie : HTTP::Cookie, uri : URI) : Bool

    abstract def return?(entry : HTTP::CookieJar::Entry, uri : URI) : Bool
  end
end
