#
# Evidence factory (backdoor logs)
#

require 'securerandom'
require 'rcs-common/crypt'
require 'rcs-common/time'
require 'rcs-common/utf16le'

# evidence types
require 'rcs-common/evidence/device'

module RCS

class Evidence
  attr_reader :size
  attr_reader :content
  attr_reader :name
  attr_reader :timestamp
  attr_reader :info
  
  include Crypt

  def initialize(key, info = {})
    @key = key
    @info = info
  end
  
  def generate_header
    thigh, tlow = @timestamp.to_filetime
    deviceid_utf16 = @info[:device_id].to_utf16le
    userid_utf16 = @info[:user_id].to_utf16le
    sourceid_utf16 = @info[:source_id].to_utf16le

    tid = @delegate.type_id
    additional_size = @delegate.additional_header.size
    struct = [2008121901, tid, thigh, tlow, deviceid_utf16.size, userid_utf16.size, sourceid_utf16.size, additional_size]
    header = struct.pack("I*")

    header += deviceid_utf16
    header += userid_utf16
    header += sourceid_utf16
    header += @delegate.additional_header

    return encrypt(header)
  end
  
  def encrypt(data)
    rest = data.size % 16
    data += "a" * (16 - rest % 16) unless rest == 0
    return aes_encrypt(data, @key, PAD_NOPAD)
  end
  
  def append_data(data, len = data.size)
    [len].pack("I") + data
  end
  
  # factory to create a random evidence
  def generate(type)
    @name =  SecureRandom.hex(16)
    @timestamp = Time.now.utc
    
    # create a delegate of the requested type
    @delegate = eval("#{type.to_s.capitalize}Evidence").new
    
    # generate header
    buf = append_data(generate_header)
    
    # append data
    chunks = @delegate.data
    chunks.each do | c |
      buf += append_data( encrypt(c), c.size )
    end
    
    @content = buf

    return self
  end
  
  def size
    @content.size
  end
  
  # save the file in the specified dir
  def dump_to_file(dir)
    # dump the file (using the @name) in the 'dir'
    File.open(dir + '/' + @name, "wb") do |f|
      f.write(@content)
    end
  end
  
  # load an evidence from a file
  def load_from_file(file)
    # load the content of the file in @content
    # TODO: it could be even delayed at the first time @content is requested
    File.open(file, "rb") do |f|
      @content = f.read
      @name = File.basename f
    end
    
    return self
  end
  
end

end # RCS::

if __FILE__ == $0
  # TODO Generated stub
end
