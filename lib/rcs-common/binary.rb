
# add a method to String to perform binary substitution
# without the hassles of regexp

class MatchNotFound < StandardError
  def initialize
    super "matching string not found"
  end
end

class String
  def binary_patch(match, replace)
    raise MatchNotFound unless self[match]
    # use the block form to avoid the regexp in the replace string
    self.gsub!(match) do |param|
      replace
    end
  end
end