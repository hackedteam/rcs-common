# here we are re-opening the ruby String class,
# the namespace must not be specified

class String

  def keywords

    # make a copy of itself to preserve the original
    keywords = self.dup

    # sanitize the input UTF-8
    keywords.encode!('UTF-8', 'UTF-8', :invalid => :replace)

    # returns a copy of str with leading and trailing whitespace removed.
    keywords.strip!

    # remove everything that is not alphanumeric
    keywords.gsub!(/([^[:alnum:]])+/u, ' ')
    #keywords.gsub!(/[(,%&@_":;!\#\-\*\[\]\{\}\?\\\+\'\.\/)]/, ' ')

    # convert to lowercase
    keywords.downcase!

    # split on spaces
    keywords = keywords.split " "

    # remove too long words
    # it is with a very high probability a meaningless word (like encoded or something)
    keywords.delete_if {|w| w.size > 25}

    # remove duplicate words
    keywords.uniq!

    # sort the array
    keywords.sort!

    keywords
  rescue Exception => e
    # fallback case
    []
  end

end

