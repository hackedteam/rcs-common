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
    
    # event
    # type
    # begin
    # end
    # info
    
    raise "Still incomplete!"
    yield info if block_given?
    :delete_raw
  end
end # ::CalendarEvidence
end # ::RCS