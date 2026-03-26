module HTTP
  class CookieJar
    module URIUtils
      extend self

      def normalize(uri : URI | String) : URI
        uri.is_a?(URI) ? uri : URI.parse(uri)
      end

      def default_path(uri : URI) : String
        path = uri.path.presence || "/"
        return "/" unless path.starts_with?('/')
        return "/" if path == "/"

        index = path.rindex('/')
        return "/" unless index && index > 0

        path[0, index]
      end

      def normalize_cookie_path(path : String?, uri : URI) : String
        return default_path(uri) unless path.presence

        normalized_path = path.not_nil!
        return default_path(uri) unless normalized_path.starts_with?('/')

        normalized_path
      end
    end
  end
end
