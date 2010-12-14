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
    # get the len
    len = self.unpack('i')
    # get the string
    unpascalized = self.slice(4, len[0]).force_encoding('UTF-16LE')
    # convert to ASCII
    unpascalized.encode!('US-ASCII')
    # remove the trailing zero
    unpascalized.chop!
    
    return unpascalized
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
      many << str
      # move the pointer after the token
      buffer = self.slice(len, self.length)
    end while buffer.length != 0
    
    return many
  end
end


if __FILE__ == $0
  source = "ciao"
  dest = ["0a0000006300690061006f000000"]
  pas = source.pascalize
  puts "Source #{source.encoding} -> " << source.unpack('H*').to_s
  puts "Pascalize (#{source.inspect}) -> [#{pas.inspect}] -> " << pas.unpack('H*').to_s
  raise "wrong conversion" unless pas.unpack('H*') == dest
  unpas = pas.unpascalize
  puts "Unpascalize (#{pas.inspect}) -> [#{unpas.inspect}] -> " << unpas.unpack('H*').to_s
  raise "wrong conversion" unless unpas == source
  
  multi_source = "\n\x00\x00\x00c\x00i\x00a\x00o\x00\x00\x00" + "\n\x00\x00\x00m\x00i\x00a\x00o\x00\x00\x00" + "\b\x00\x00\x00b\x00a\x00o\x00\x00\x00"
  multi = multi_source.unpascalize_ary
  puts "Multi source: " << multi.to_s
  
end