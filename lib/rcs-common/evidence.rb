#
# Evidence factory (backdoor logs)
#

require 'securerandom'
require 'rcs-common/crypt'

class Time
  # Convert the time to the FILETIME format, a 64-bit value representing the
  # number of 100-nanosecond intervals since January 1, 1601 (UTC).
  def wtime
    t = self.to_i + 11644473600
    t *= 10000000
    return (t & 0xFFFFFFFF00000000) >> 32, (t & 0xFFFFFFFF)
  end

  # Create a time object from the FILETIME format, a 64-bit value representing
  # the number of 100-nanosecond intervals since January 1, 1601 (UTC).
  def self.from_wtime(wtime)
    Time.at((wtime - 116444736000000000) / 10000000)
  end
end

class String
  def to_utf16le
    self.encode('UTF-16LE').unpack("H*").pack("H*")
  end
end

module RCS

class DeviceEvidence
  def additional_header
    ''
  end

  def type_id
    0x0240
  end

  def data
    "The time is #{Time.now}".to_utf16le
  end
end

class Evidence
  attr_reader :size
  attr_reader :content
  attr_reader :name
  attr_reader :timestamp
  attr_reader :info
  
  include Crypt
  
  def initialize(key, info = {})
    @key = key
    @info = info
  end

  def generate_header
    thigh, tlow = @timestamp.wtime
    deviceid_utf16 = @info[:device_id].to_utf16le
    userid_utf16 = @info[:user_id].to_utf16le
    sourceid_utf16 = @info[:source_id].to_utf16le

    tid = @delegate.type_id
    additional_size = @delegate.additional_header.size
    struct = [2008121901, tid, thigh, tlow, deviceid_utf16.size, userid_utf16.size, sourceid_utf16.size, additional_size]
    header = struct.pack("I*")

    header += deviceid_utf16
    header += userid_utf16
    header += sourceid_utf16
    header += @delegate.additional_header

    return header
  end
  
  def encrypt(data)
    rest = data.size % 16
    data += "a" * (16 - rest % 16) unless rest == 0
    return aes_encrypt(data, @key, PAD_NOPAD)
  end
  
  def obfuscate
    header = generate_header
    encrypted_header = encrypt(header)

    source = [encrypted_header.size].pack("I")
    source += encrypted_header

    source += [@delegate.data.size].pack("I")
    encrypted_data = encrypt(@delegate.data)
    source += encrypted_data

    return source
  end

  # factory to create a random evidence
  def generate(type)
    @name =  SecureRandom.hex(16)
    @timestamp = Time.now.utc

    @delegate = eval("#{type.to_s.capitalize}Evidence").new
    @content = obfuscate
    @size = @content.length

    return self
  end

  # save the file in the specified dir
  def dump_to_file(dir)
    # dump the file (using the @name) in the 'dir'
    File.open(dir + '/' + @name, "w") do |f|
      f.write(@content)
    end
  end

  # load an evidence from a file
  def load_from_file(file)
    # load the content of the file in @content
    # TODO: it could be even delayed at the first time @content is requested
    File.open(file, "r") do |f|
      @content = f.read
    end
    
    return self
  end

end

end # RCS::

if __FILE__ == $0
  # TODO Generated stub
end