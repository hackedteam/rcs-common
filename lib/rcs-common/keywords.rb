# here we are re-opening the ruby String class,
# the namespace must not be specified

class String

  def keywords

    # make a copy of itself to preserve the original
    keywords = self.dup

    # convert to lowercase
    keywords.downcase!

    # returns a copy of str with leading and trailing whitespace removed.
    keywords.strip!

    # remove everything that is not alphanumeric
    keywords.gsub!(/([^[:alnum:]])+/u, ' ')
    #keywords.gsub!(/[(,%&@_":;!\#\-\*\[\]\{\}\?\\\+\'\.\/)]/, ' ')

    # split on spaces
    keywords = keywords.split " "

    # remove duplicate words
    keywords.uniq!

    # sort the array
    keywords.sort!

    keywords
  end

end

