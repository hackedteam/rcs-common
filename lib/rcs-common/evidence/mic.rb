require_relative 'common'
require 'rcs-common/serializer'

module RCS
module MicEvidence

    MIC_LOG_VERSION = 2008121901

    def decode_additional_header(data)

    raise EvidenceDeserializeError.new("incomplete evidence") if data.nil? or data.bytesize == 0

    stream = StringIO.new data

    ret = Hash.new
    ret[:data] = Hash.new

    version = read_uint32 stream
    raise EvidenceDeserializeError.new("invalid log version for voice call") unless version == MIC_LOG_VERSION

    ret[:data][:sample_rate] = read_uint32 stream
    low, high = stream.read(8).unpack 'V2'
    ret[:data][:mic_id] = Time.from_filetime high, low

    return ret
  end

  def decode_content(common_info, chunks)
    stream = StringIO.new chunks.join

    info = Hash[common_info]
    info[:data] ||= Hash.new

    info[:data][:grid_content] = chunks.join
    yield info if block_given?
    :keep_raw
  end
end # ::CalendarEvidence
end # ::RCS