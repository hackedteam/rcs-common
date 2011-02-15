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

class Evidence
  attr_reader :size
  attr_reader :content
  attr_reader :name
  attr_reader :timestamp

  @@logtype = { :DEVICE => 0x0240 }

  include Crypt

  def initialize(log_key, deviceid, userid, sourceid)
    @key = log_key
    @deviceid = deviceid
    @userid = userid
    @sourceid = sourceid
  end

  def generate_header(type, additional = '')
    thigh, tlow = @timestamp.wtime
    deviceid_utf16 = @deviceid.to_utf16le
    userid_utf16 = @userid.to_utf16le
    sourceid_utf16 = @sourceid.to_utf16le

    struct = [2008121901, @@logtype[:DEVICE], thigh, tlow, deviceid_utf16.size, userid_utf16.size, sourceid_utf16.size, additional.size]
    header = struct.pack("I*")

    header += deviceid_utf16
    header += userid_utf16
    header += sourceid_utf16
    header += additional

    return header
  end

  def encrypt(data)
    rest = data.size % 16
    data += "a" * (16 - rest % 16) unless rest == 0
    return aes_encrypt(data, @key, PAD_NOPAD)
  end

  def obfuscate(type, data)
    header = generate_header(type)
    encrypted_header = encrypt(header)

    source = [encrypted_header.size].pack("I")
    source += encrypted_header

    source += [data.size].pack("I")
    encrypted_data = encrypt(data)
    source += encrypted_data

    return source
  end

  # factory to create a random evidence
  def generate(type)
    @name =  SecureRandom.hex(16)
    @timestamp = Time.now.utc

    @content = obfuscate(type, "The time is #{Time.now}".to_utf16le)
    @size = @content.length

    return self
  end

end

end # RCS::

if __FILE__ == $0
  # TODO Generated stub
end