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
    @info[:channel] = CHANNEL[data.slice!(0..3).unpack("I").shift]
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
    
    @info[:caller] = data.slice!(0..caller_len-1) unless caller_len == 0
    @info[:callee] = data.slice!(0..callee_len-1) unless callee_len == 0
  end

  def decode_content(chunks)
    chunks.each do |c|
      puts "Chunk of size #{c.size}"
    end
  end

end

end # RCS::