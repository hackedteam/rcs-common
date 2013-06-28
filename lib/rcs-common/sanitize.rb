# encoding: utf-8

# here we are re-opening the ruby String class,
# the namespace must not be specified

class String

  def remove_invalid_chars

    # remove invalid UTF-8 chars
    self.encode('UTF-8', self.encoding.to_s, :invalid => :replace).gsub(/([^[:alnum:][:graph:]\n\r])+/u, ' ')
  end

  def strip_html_tags
    copy = self.dup

    # Strip HTML tags
    copy.gsub!(/<[^>]*>/, '')

    # Strip encoded &amp; repetitively encoded HTML tags
    copy.gsub!(/&amp;(amp;)*lt;.*?&amp;(amp;)*gt;/im, '')

    # Strip HTML entities and repetitively encoded entities
    # Or decode with http://htmlentities.rubyforge.org/
    copy.gsub!(/&amp;(amp;)*((#x?)?[a-f0-9]+|[a-z]+);/i, ' ')

    copy
  end

end
