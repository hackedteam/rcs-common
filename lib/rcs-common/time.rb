#
# Helper methods for decoding Windows FILETIME structs.
#

class Time
  # Convert the time to the FILETIME format, a 64-bit value representing the
  # number of 100-nanosecond intervals since January 1, 1601 (UTC).
  def to_filetime
    t = self.to_f + 11644473600
    t *= 10000000
    t = t.to_i
    return (t & 0xFFFFFFFF), (t & 0xFFFFFFFF00000000) >> 32
  end
  
  # Create a time object from the FILETIME format, a 64-bit value representing
  # the number of 100-nanosecond intervals since January 1, 1601 (UTC).
  def self.from_filetime(high, low)
    wtime = Float((high << 32) | low)
    unix_hundreds_nanosec = wtime - 116_444_736_000_000_000
    seconds_with_frac = unix_hundreds_nanosec / 10_000_000
    
    return Time.at(seconds_with_frac).getutc
  end
end
