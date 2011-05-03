require 'rcs-common/evidence/common'
require 'rcs-common/poom_serializer'

module RCS
module AddressbookEvidence
  def content
    raise "Not implemented!"
  end

  def generate_content
    raise "Not implemented!"
  end

  def decode_content
    stream = StringIO.new @info[:chunks].join
    #size = read_uint32 stream
    #puts "Size => #{size}"

    @poom = PoomSerializer.new.unserialize stream
    
    @info[:contact_name] = @poom.name
    @info[:contact_email] = @poom.contact
    @info[:contact_info] = @poom.info
    
    return [self]
  end
end # ::AddressbookEvidence
end # ::RCS