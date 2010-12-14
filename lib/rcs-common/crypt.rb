#
# The encryption module.
#   by default we use the PKCS5 padding
#   force the third parameter to change the padding
#

require 'openssl'

module RCS

module Crypt
  PAD_NOPAD = 0
  PAD_PKCS5 = 1
  
  def aes_encrypt(clear_text, key, padding=PAD_PKCS5)
    cipher = OpenSSL::Cipher::Cipher.new('aes-128-cbc')
    cipher.encrypt
    cipher.padding = padding
    cipher.key = key
    cipher.iv = "\x00" * cipher.iv_len
    edata = cipher.update(clear_text)
    edata << cipher.final
    return edata
  end
  
  def aes_decrypt(enc_text, key, padding=PAD_PKCS5)
    decipher = OpenSSL::Cipher::Cipher.new('aes-128-cbc')
    decipher.decrypt
    decipher.padding = padding
    decipher.key = key
    decipher.iv = "\x00" * decipher.iv_len
    data = decipher.update(enc_text)
    data << decipher.final
    return data
  end
  
end

end #namespace

if __FILE__ == $0
  require 'securerandom'
  include RCS::Crypt
  
  clear = SecureRandom.random_bytes(16)
  key = Digest::MD5.digest "4yeN5zu0+il3Jtcb5a1sBcAdjYFcsD9z"
  
  puts "DATA: " + clear.unpack('H*').to_s
  enc = aes_encrypt(clear, key)
  
  puts "ENC: " + enc.unpack('H*').to_s
  dec = aes_decrypt(enc, key)
  
  puts "DEC: " + dec.unpack('H*').to_s
  
end
