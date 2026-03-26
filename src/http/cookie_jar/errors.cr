module HTTP
  class CookieJar
    class Error < Exception
    end

    class InvalidCookie < Error
    end
  end
end
