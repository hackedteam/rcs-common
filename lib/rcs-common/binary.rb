
# add a method to String to perform binary substitution
# without the hassles of regexp

class MatchNotFound < StandardError
  def initialize
    super "matching string not found"
  end
end

class OutOfBounds < StandardError
  def initialize
    super "offset is out of bound"
  end
end

class OutOfBoundsString < StandardError
  def initialize
    super "string too long, out of bound"
  end
end

class String
  def binary_patch(match, replace)
    raise MatchNotFound unless self[match]
    # use the block form to avoid the regexp in the replace string
    self.gsub!(match.force_encoding('ASCII-8BIT')) do |param|
      replace.force_encoding('ASCII-8BIT')
    end
  end

  def binary_patch_at_offset(offset, replace)
    io = StringIO.new(self)

    # check for boundaries
    raise OutOfBounds if offset < 0
    raise OutOfBounds if offset > io.size
    raise OutOfBoundsString if offset + replace.bytesize > io.size

    io.pos = offset
    io.write replace
    io.close
  end

end