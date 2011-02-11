#
#  Mime Types handling module
#

# system
require 'mime/types'

# reopen the original class in order to add our specific mime types
module MIME
  class Types
    # rename the original method to be used in our wrapper
    alias mime_type_for type_for
    
    # our wrapper which adds our types
    def type_for(filename, platform = false)
      # call the original method
      type = mime_type_for(filename, platform)
      
      if type.empty? then
        case File.extname(filename)
          when '.cod'
            type = MIME::Type.from_array('application/vnd.rim.cod', 'cod', '8bit', 'linux')
          when '.apk'
            type = MIME::Type.from_array('application/vnd.android.package-archive', 'apk', '8bit', 'linux')
        end
      end
      return type
    end
  end
end

module RCS

class MimeType

  def self.get(file)
    # ask for the mime type
    type = MIME::Types.type_for(file)
    
    # if there are multiple choices, get the first one
    type = type.first if type.is_a?(Array)

    # special case for IE mobile not understanding this
    if File.extname(file) == '.cab' then
      type = MIME::Type.new('binary/octet-stream')
    end

    # default if none is found
    type = MIME::Type.new('binary/octet-stream') if type.nil?

    # convert from MIME::Type to String
    return type.to_s
  end
end

end #RCS::

