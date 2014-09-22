require 'mongoid'

# Monkey path serialization of BSON::ObjectId
module BSON
  class ObjectId
    def as_json(*args)
      to_s
    end
  end
end
