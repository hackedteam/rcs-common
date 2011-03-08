
module ByteSize

  KiB = 1024
  MiB = KiB * 1024
  GiB = MiB * 1024
  TiB = GiB * 1024

  def to_s_bytes
    # return the size in a human readable format
    if self >= TiB then
      return (self.to_f / TiB).round(2).to_s + ' TiB'
    elsif self >= GiB then
      return (self.to_f / GiB).round(2).to_s + ' GiB'
    elsif self >= MiB
      return (self.to_f / MiB).round(2).to_s + ' MiB'
    elsif self >= KiB
      return (self.to_f / KiB).round(2).to_s + ' KiB'
    else
      return self.to_s + ' B'
    end
  end

end

class Fixnum
  include ByteSize
end

# we need to add it even to Bignum for windows32 compatibility
# everything ove a GiB is Bignum...
class Bignum
  include ByteSize
end