require_relative 'common'
require 'rcs-common/serializer'

module RCS
module MessageEvidence
  def content
    raise "Not implemented!"
  end

  def generate_content
    raise "Not implemented!"
  end

  def decode_content(common_info, chunks)
    stream = StringIO.new chunks.join
    
    info = Hash[common_info]
    info[:data] ||= Hash.new
    
    # from
    # rcpt
    # subject
    # size
    # status
    # content
    # blob
    
    raise "Still incomplete!"
    yield info if block_given?
    :delete_raw
  end
end # ::CalendarEvidence
end # ::RCS