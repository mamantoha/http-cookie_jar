module HTTP
  abstract class FileCookieJar < CookieJar
    property filename : String?

    def initialize(
      @filename : String? = nil,
      policy : HTTP::CookiePolicy = HTTP::DefaultCookiePolicy.new,
    )
      super(policy: policy)
    end

    def save(path : String? = @filename, include_session : Bool = false) : Nil
      file = path || raise ArgumentError.new("Missing cookie jar filename")

      File.open(file, "w") do |io|
        write(io, include_session: include_session)
      end
    end

    def load(path : String? = @filename) : self
      file = path || raise ArgumentError.new("Missing cookie jar filename")

      clear
      File.open(file) do |io|
        read(io)
      end

      clear_expired
      self
    end

    protected abstract def write(io : IO, include_session : Bool = false) : Nil

    protected abstract def read(io : IO) : Nil
  end
end
