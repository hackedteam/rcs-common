require 'mongoid'

# Monkey path serialization of BSON::ObjectId
module BSON
  class ObjectId
    def as_json(*args)
      to_s
    end
  end
end

# Fix #symbolize_key called on BSON::Document
module BSON
  class Document < ::Hash
    def symbolize_keys
      to_h.symbolize_keys
    end
  end
end
