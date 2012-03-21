
# add a method to String to perform binary substitution
# without the hassles of regexp

class String
  def binary_patch(match, replace)
    # use the block form to avoid the regexp in the replace string
    self.gsub!(match) {|param| replace }
  end
end