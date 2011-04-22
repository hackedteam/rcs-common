
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
    
    @info[:channel] = CHANNEL[read_uint32 binary]
    @info[:software] = SOFTWARE[read_uint32 binary]
    @info[:sample_rate] = read_uint32 binary
    @info[:incoming] = read_uint32 binary
    low = read_uint32 binary
    high = read_uint32 binary
    @info[:start_time] = Time.from_filetime high, low
    low = read_uint32 binary
    high = read_uint32 binary
    @info[:stop_time] = Time.from_filetime high, low

    caller_len = read_uint32 binary
    callee_len = read_uint32 binary
    
    raise RCS::EvidenceDeserializeError.new("invalid callee") if callee_len == 0
    
    @info[:caller] ||= binary.read(caller_len).utf16le_to_utf8.lstrip.rstrip if caller_len != 0
    @info[:callee] ||= binary.read(callee_len).utf16le_to_utf8.lstrip.rstrip if callee_len != 0
  end
  
  def end_call?
    return true if @content.bytesize == 4 and @content == "\xff\xff\xff\xff"
  end
  
  def decode_content
    @content = @info[:chunks].join
    return [self]
  end
  
end

end # RCS::