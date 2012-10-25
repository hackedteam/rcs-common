# encoding: utf-8

# here we are re-opening the ruby String class,
# the namespace must not be specified

class String

  def remove_invalid_chars

    # remove invalid UTF-8 chars
    self.encode('UTF-8', 'UTF-8', :invalid => :replace).gsub(/([^[:alnum:][:graph:]\n\r])+/u, ' ')

  end

end

