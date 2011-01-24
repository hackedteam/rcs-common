# here we are re-opening the ruby String class,
# the namespace must not be specified

class String
  
  # returns a string encoded into a pascalized form
  def pascalize
    # the pascalized version is composed as follow:
    # - 4 bytes len in front
    # - UTF-16LE encoded string
    # - UTF-16LE null terminator
    pascalized = [self.encode('UTF-16LE').bytesize + 2].pack('i') 
    pascalized += self.encode('UTF-16LE').unpack('H*').pack('H*') 
    pascalized += "\x00\x00"
    
    return pascalized
  end
  
  # returns a string decoded from its pascalized form
  def unpascalize
    begin
      # get the len
      len = self.unpack('i')
      # get the string
      unpascalized = self.slice(4, len[0]).force_encoding('UTF-16LE')
      # convert to ASCII
      unpascalized.encode!('US-ASCII')
      # remove the trailing zero
      unpascalized.chop!

      return unpascalized
    rescue
      return 
    end
  end

  # returns an array containing all the concatenated pascalized strings
  def unpascalize_ary
    many = []
    buffer = self
    len = 0
    
    begin
      # len of the current token
      len += buffer.unpack('i')[0] + 4
      # unpascalize the token
      str = buffer.unpascalize
      # add to the result array
      many << str unless str.nil?
      # move the pointer after the token
      buffer = self.slice(len, self.length)
      # sanity check
      break if buffer.nil?
    end while buffer.length != 0
    
    return many
  end
end

