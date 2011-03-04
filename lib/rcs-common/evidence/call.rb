
require 'rcs-common/evidence/common'

module RCS

module CallEvidence

  LOG_VOICE_VERSION = 2008121901
  CHANNEL = { 0 => :INCOMING, 1 => :OUTGOING }
  PROGRAM = { 0x0141 => :SKYPE,
              0x0142 => :GTALK,
              0x0143 => :YAHOO,
              0x0144 => :MSN,
              0x0145 => :MOBILE,
              0x0146 => :SKYPE_WSAPI,
              0X0147 => :MSN_WSAPI }

  class CallAdditionalHeader < FFI::Struct
    layout :version, :uint32,
           :channel, :uint32,
           :software, :uint32,
           :sample_rate, :uint32,
           :incoming, :uint32,
           :starttime_l, :uint32,
           :starttime_h, :uint32,
           :stoptime_l, :uint32,
           :stoptime_h, :uint32,
           :caller_len, :uint32,
           :callee_len, :uint32
  end

  attr_reader :channel
  attr_reader :made_using
  attr_reader :sample_rate
  attr_reader :start_time
  attr_reader :stop_time
  attr_reader :caller
  attr_reader :callee

  def type_id
    0x0140
  end
  
  def decode_additional_header(data)
    
    return nil if data.nil? or data.size == 0
    
    binary = StringIO.new data
    header_ptr = FFI::MemoryPointer.from_string binary.read CallAdditionalHeader.size
    header = CallAdditionalHeader.new header_ptr
    
    puts "#{binary.size}:#{CallAdditionalHeader.size}, version #{header[:version]}"
        
    @channel = CHANNEL[header[:channel]]
    @made_using = PROGRAM[header[:software]]
    
    @sample_rate = header[:sample_rate]
    
    @start_time = Time.from_filetime header[:starttime_h], header[:starttime_l]
    @stop_time = Time.from_filetime header[:stoptime_h], header[:stoptime_l]
    
    @caller = ''
    @caller = binary.read(header[:caller_len]).force_encoding('UTF-16LE').encode!('UTF-8').lstrip.rstrip if header[:caller_len] != 0
    
    @callee = ''
    @callee = binary.read(header[:callee_len]).force_encoding('UTF-16LE').encode!('UTF-8').lstrip.rstrip if header[:callee_len] != 0
    
  end
  
  def decode_content(chunks)
    chunks
  end
  
end

end # RCS::