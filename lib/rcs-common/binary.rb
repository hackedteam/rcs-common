
# add a method to String to perform binary substitution
# without the hassles of regexp

class String
  def binary_patch(match, replace)
    raise "matching string not found" unless self[match]
    # use the block form to avoid the regexp in the replace string
    self.gsub!(match) do |param|
      replace
    end
  end
end