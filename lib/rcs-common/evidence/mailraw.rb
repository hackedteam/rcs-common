require 'mail'
require_relative 'common'

module RCS
module MailrawEvidence
  MAILRAW_VERSION = 2009070301
  
  def decode_additional_header(data)
    raise EvidenceDeserializeError.new("incomplete MAILRAW") if data.nil? or data.bytesize == 0
    
    binary = StringIO.new data

    version, flags, size, ft_low, ft_high = binary.read(20).unpack('I*')
    raise EvidenceDeserializeError.new("invalid log version for MOUSE") unless version == MAILRAW_VERSION
    
    @info[:size] = size
    @info[:acquired] = Time.from_filetime(ft_high, ft_low)
  end

  def decode_content
    @info[:content] = @info[:chunks].join
    @info[:size] = @info[:content].bytesize
    @info[:status] = 0

    return [self]
  end
end # ::Mailraw
end # ::RCS