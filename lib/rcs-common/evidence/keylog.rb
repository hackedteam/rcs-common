# encoding: utf-8

require 'rcs-common/evidence/common'

module RCS

module KeylogEvidence

  ELEM_DELIMITER = 0xABADC0DE
  KEYSTROKES = ["привет мир", "こんにちは世界", "Hello world!", "Ciao mondo!"]
  
  def content
    proc_name = "ruby".to_utf16le_binary_null
    window_name = "Ruby Backdoor!".to_utf16le_binary_null
    content = StringIO.new
    t = Time.now.getutc
    content.write [t.sec, t.min, t.hour, t.mday, t.mon, t.year, t.wday, t.yday, t.isdst ? 0 : 1].pack('l*')
    content.write proc_name
    content.write window_name
    content.write [ ELEM_DELIMITER ].pack('L*')
    keystrokes = KEYSTROKES.sample.to_utf16le_binary_null
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
      @info[:process] = ''
      @info[:window] = ''
      @info[:keystrokes] = ''
      
      process_name = stream.read_utf16le_string
      @info[:process] = process_name.utf16le_to_utf8 unless process_name.nil?
      window_name = stream.read_utf16le_string
      @info[:window] = window_name.utf16le_to_utf8 unless window_name.nil?
      
      delim = stream.read(4).unpack("L*").first
      raise EvidenceDeserializeError.new("Malformed evidence (missing delimiter)") unless delim == ELEM_DELIMITER
      
      keystrokes = stream.read_utf16le_string
      @info[:keystrokes] = keystrokes.utf16le_to_utf8 unless keystrokes.nil?
      
      # this is not the real clone! redefined clone ...
      evidences << self.clone
    end
    
    return evidences
  end
end

end # ::RCS