module HTTP
  class CookieJar
    def to_json(json : JSON::Builder) : Nil
      json.object do
        json.field "entries" do
          json.array do
            each do |entry|
              entry.to_json(json)
            end
          end
        end
      end
    end

    def self.from_json(source : String | IO, policy : HTTP::CookiePolicy = HTTP::DefaultCookiePolicy.new) : self
      data = JSON.parse(source)
      jar = new(policy: policy)

      data["entries"].as_a.each do |value|
        jar.add_entry(Entry.from_json(value))
      end

      jar.clear_expired
      jar
    end
  end
end
