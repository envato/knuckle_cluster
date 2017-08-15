require 'json'

module CoreExtensions
  module Hash
    def symbolize_keys
      JSON.parse(to_json,symbolize_names: true)
    end
  end
end
