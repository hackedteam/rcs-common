#
# Helper method for decoding windows WCHAR strings.
#

class String
  def to_utf16le_binary
    self.encode('UTF-16LE').unpack("H*").pack("H*")
  end
end
