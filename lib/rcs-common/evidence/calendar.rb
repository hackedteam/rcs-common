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
    stream = StringIO.new @info[:chunks].join

    @calendar = CalendarSerializer.new.unserialize stream

    raise "Still incomplete!"
    return [self]
  end
end # ::CalendarEvidence
end # ::RCS