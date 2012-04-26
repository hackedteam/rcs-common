
module ByteSize

  KiB = 2**10
  MiB = 2**20
  GiB = 2**30
  TiB = 2**40

  KB = 10**3
  MB = 10**6
  GB = 10**9
  TB = 10**12

  # return the size in a human readable format
  def to_s_bytes(base = 2)

    base_two = {TiB => 'TiB', GiB => 'GiB', MiB => 'MiB', KiB => 'KiB'}
    base_ten = {TB => 'TB', GB => 'GB', MB => 'MB', KB => 'kB'}

    values = base_two if base == 2
    values = base_ten if base == 10

    values.each_pair do |k, v|
      if self >= k
        return (self.to_f / k).round(2).to_s + ' ' + v
      end
    end

    # case when is under KiB
    return self.to_s + ' B'

  end

end

class Fixnum
  include ByteSize
end

# we need to add it even to Bignum for windows32 compatibility
# everything over a GiB is Bignum...
class Bignum
  include ByteSize
end