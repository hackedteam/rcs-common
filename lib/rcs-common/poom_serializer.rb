require 'stringio'

module RCS
class PoomSerializer
  attr_reader :name, :contact, :info
  
  POOM_MASK = 0x00FFFFFF
  
  POOM_TYPES = { 0x1 => :first_name,
                 0x2 => :last_name, 
                 0x3 => :company,
                 0x4 => :business_fax_number,
                 0x5 => :department,
                 0x6 => :email_1,
                 0x7 => :mobile_phone,
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
                 21=>:children,
                 22=>:categories,
                 23=>:web_page,
                 24=>:business_2_phone_number,
                 25=>:radio_phone_number,
                 26=>:file_as,
                 27=>:yomi_company_name,
                 28=>:yomi_first_name,
                 29=>:yomi_last_name,
                 30=>:title,
                 31=>:middle_name,
                 32=>:suffix,
                 33=>:home_address_street,
                 34=>:home_address_city,
                 35=>:home_address_state,
                 36=>:home_address_postal_code,
                 37=>:home_address_country,
                 38=>:other_address_street,
                 39=>:other_address_city,
                 40=>:other_address_postal_code,
                 41=>:other_address_country,
                 42=>:business_address_street,
                 43=>:business_address_city,
                 44=>:business_address_state,
                 45=>:business_address_postal_code,
                 46=>:business_address_country,
                 47=>:other_address_state,
                 48=>:body,
                 49=>:birthday,
                 50=>:anniversary,
                 51=>:skype_name,
                 52=>:phone_numbers,
                 53=>:address,
                 54=>:notes,
                 55=>:unknown}
  
  def initialize
    @fields = {}
    @poom_strings = {}
    POOM_TYPES.each_pair do |k, v|
      @poom_strings[v] = v.to_s.gsub(/_/, " ").capitalize.encode('UTF-8')
    end
  end
  
  def unserialize(stream)
    # discard header
    stream.read(12)
    
    @fields = {}
    until stream.eof? do
      type, size = unserialize_entry stream
      @fields[type] = stream.read(size).utf16le_to_utf8
    end
    
    # name
    @name = @fields[:first_name] if @fields.has_key? :first_name
    @name += " " + @fields[:last_name] if @fields.has_key? :last_name
    
    # contact
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
    
    # info
    @info = ""
    omitted_fields = [:first_name, :last_name, :body, :file_as]
    @fields.each_pair do |k, v|
      next if omitted_fields.include? k
      @info += @poom_strings[k]
      @info += ": "
      @info += v
      @info += "\n"
    end
    
    return self
  end
  
  def unserialize_entry(stream)
    type, size = read_prefix stream
    return POOM_TYPES[type], size
  end
  
  def read_prefix(stream)
    prefix = stream.read(4).unpack("L").shift
    type, size = (prefix & ~POOM_MASK) >> 0x18, prefix & POOM_MASK
  end
end # ::PoomSerializer
end # ::RCS