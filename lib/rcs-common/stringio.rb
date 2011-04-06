require 'stringio'

class StringIO
  def read_utf16_string
    return nil if self.size < 2
    str = self.read(2)
    until str[-2,2] == "\0\0" or self.tell == self.size do
      str += self.read(2)
    end
    return nil if str.bytesize % 2 != 0
    str
  end
end