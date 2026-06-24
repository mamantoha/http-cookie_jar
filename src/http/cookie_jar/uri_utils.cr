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
        if normalized_path = path
          if normalized_path.starts_with?('/')
            normalized_path
          else
            default_path(uri)
          end
        else
          default_path(uri)
        end
      end
    end
  end
end
