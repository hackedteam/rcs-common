require 'rcs-common/evidence/common'
require 'mail'

module RCS
module MailrawEvidence

  MAILRAW_VERSION = 2009070301

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
    
    binary = StringIO.new data

    version, flags, size, ft_low, ft_high = binary.read(20).unpack('I*')
    raise EvidenceDeserializeError.new("invalid log version for MOUSE") unless version == MAILRAW_VERSION
    
    @info[:size] = size
    @info[:acquired] = Time.from_filetime(ft_high, ft_low)
  end

  def decode_content
    @info[:content] = @info[:chunks].join
    @info[:size] = @info[:content].bytesize
    @info[:status] = 0

    return [self]
  end
end # ::Mailraw
end # ::RCS