# encoding: utf-8

# here we are re-opening the ruby String class,
# the namespace must not be specified

class String
  REMOVE_INVALID_CHARS_REGEXP = Regexp.new(/([^[:alnum:][:graph:]\n\r])+/u)

  def remove_invalid_chars
    self.force_utf8.gsub(REMOVE_INVALID_CHARS_REGEXP, ' ')
  end

  def force_utf8(modify_self = false)
    src_encoding = valid_encoding? ? encoding.to_s : 'BINARY'
    dst_encoding = 'UTF-8'

    args = [dst_encoding, src_encoding, {:invalid => :replace, :undef => :replace, replace: ''}]

    modify_self ? encode!(*args) : encode(*args)
  end

  def force_utf8!
    force_utf8(true)
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
