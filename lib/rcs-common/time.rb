#
# Helper methods for decoding Windows FILETIME structs.
#

class Time
  # Convert the time to the FILETIME format, a 64-bit value representing the
  # number of 100-nanosecond intervals since January 1, 1601 (UTC).
  def to_filetime
    t = self.to_i + 11644473600
    t *= 10000000
    return (t & 0xFFFFFFFF00000000) >> 32, (t & 0xFFFFFFFF)
  end

  # Create a time object from the FILETIME format, a 64-bit value representing
  # the number of 100-nanosecond intervals since January 1, 1601 (UTC).
  def self.from_filetime(wtime)
    Time.at((wtime - 116444736000000000) / 10000000)
  end
end

