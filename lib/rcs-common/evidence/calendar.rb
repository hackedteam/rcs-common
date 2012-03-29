require_relative 'common'
require 'rcs-common/serializer'

module RCS
module CalendarEvidence
  def content
    raise "Not implemented!"
  end

  def generate_content
    raise "Not implemented!"
  end

  def decode_content(common_info, chunks)
    stream = StringIO.new chunks.join

    info =  Hash[common_info]
    info[:data] ||= Hash.new

    @calendar = CalendarSerializer.new.unserialize stream

    info[:data][:event] = @calendar.fields[:subject]
    info[:data][:type] = @calendar.fields[:categories]
    info[:data][:begin] = @calendar.start_date
    info[:data][:end] = @calendar.end_date

    unless @calendar.fields[:recipients].nil?
      recipients = @calendar.fields[:recipients]
      info[:data][:recipients] = recipients unless recipients.empty?
    end

    unless @calendar.fields[:location].nil?
      location = @calendar.fields[:location]
      info[:data][:location] = location unless location.empty?
    end

    unless @calendar.fields[:body].nil?
      body = @calendar.fields[:body]
      info[:data][:body] = body unless body.empty?
    end

    yield info if block_given?
    :keep_raw
  end
end # ::CalendarEvidence
end # ::RCS
