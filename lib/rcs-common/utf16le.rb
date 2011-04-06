#
# Helper method for decoding windows WCHAR strings.
#

class String
  def to_binary
    self.unpack("H*").pack("H*")
  end

  def to_utf16le_binary
    self.encode('UTF-16LE').to_binary
  end

  def utf16le_to_utf8
    self.force_encoding('UTF-16LE').encode('UTF-8')
  end
end
