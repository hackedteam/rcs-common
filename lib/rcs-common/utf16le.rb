#
# Helper method for decoding windows WCHAR strings.
#

require 'stringio'

class StringIO
  def read_utf16le_string
    # at least the null terminator
    return '' if self.size < 2

    # empty string by default
    str = ''
    # read until the end of buffer or null termination
    until self.eof? do
      t = self.read(2)
      break if t == "\0\0"
      str << t
    end

    # misaligned string
    return '' if str.bytesize % 2 != 0

    return str
  end

  def read_ascii_string
    # at least the null terminator
    return '' if self.size < 1

    # empty string by default
    str = ''
    # read until the end of buffer or null termination
    until self.tell == self.size do
      t = self.read(1)
      break if t == "\0"
      str << t
    end

    return str
  end

end

class String
  def to_binary
    self.unpack("H*").pack("H*")
  end

  def to_utf16le_binary
    self.encode('UTF-16LE').to_binary
  end

  def to_utf16le_binary_null
    # with null termination
    (self + "\0").to_utf16le_binary
  end

  def terminate_utf16le
    self.force_encoding('UTF-16LE') + "\0".encode('UTF-16LE')
  end

  def to_utf16le
    self.encode('UTF-16LE')
  end

  def utf16le_to_utf8
    self.force_encoding('UTF-16LE').encode('UTF-8').chomp("\0")
  end

  def safe_utf8_encode_invalid
    return self if self.encoding == Encoding::UTF_8 and self.valid_encoding?
    self.safe_utf8_encode
    return self if self.valid_encoding?
    self.force_encoding('BINARY')
    self.encode! 'BINARY', 'UTF-8', invalid: :replace, undef: :replace, replace: '?'
  end

  def safe_utf8_encode
    self.force_encoding('UTF-8')
    self.encode! 'UTF-8', 'UTF-8', invalid: :replace, undef: :replace, replace: ''
  end
end
