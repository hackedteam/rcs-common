# here we are re-opening the ruby String class,
# the namespace must not be specified

class String

  def keywords

    # convert to lowercase
    self.downcase!

    # returns a copy of str with leading and trailing whitespace removed.
    self.strip!

    # remove punctuation
    if self.ascii_only?
      self.gsub!(/(\W)+/u, ' ')
    else
      self.gsub!(/[(,?!\'":;.)]/, ' ')
    end

    # split on spaces
    keywords = self.split " "

    # remove duplicate words
    keywords.uniq!

    # sort the array
    keywords.sort!

    keywords
  end

end

