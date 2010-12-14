require 'helper'
require 'securerandom'

class TestRcsCommon < Test::Unit::TestCase

  include RCS::Crypt

  def test_crypt_multiple_of_block_size

    clear = SecureRandom.random_bytes(16)
    key = Digest::MD5.digest "4yeN5zu0+il3Jtcb5a1sBcAdjYFcsD9z"

    # padding is ON by default
    enc = aes_encrypt(clear, key)

    # must be multiple of block_len
    assert_true enc.length % 16 == 0

    dec = aes_decrypt(enc, key)

    assert_equal clear, dec
  end

  def test_crypt_not_multiple_of_block_size

    clear = SecureRandom.random_bytes(19)
    key = Digest::MD5.digest "4yeN5zu0+il3Jtcb5a1sBcAdjYFcsD9z"

    # padding is ON by default
    enc = aes_encrypt(clear, key)

    # must be multiple of block_len
    assert_true enc.length % 16 == 0

    dec = aes_decrypt(enc, key)

    assert_equal clear, dec
  end

  def test_crypt_multiple_of_block_size_no_pad

    clear = SecureRandom.random_bytes(16)
    key = Digest::MD5.digest "4yeN5zu0+il3Jtcb5a1sBcAdjYFcsD9z"

    # padding is ON by default
    enc = aes_encrypt(clear, key, PAD_NOPAD)

    # must be exactly the same size
    assert_true enc.length == clear.length

    dec = aes_decrypt(enc, key, PAD_NOPAD)

    assert_equal clear, dec
  end

  def test_crypt_not_multiple_of_block_size_no_pad

    clear = SecureRandom.random_bytes(19)
    key = Digest::MD5.digest "4yeN5zu0+il3Jtcb5a1sBcAdjYFcsD9z"

    # padding is ON by default
    enc = aes_encrypt(clear, key, PAD_NOPAD)

    # must be exactly the same size
    assert_true enc.length == clear.length

    assert_raise(OpenSSL::Cipher::CipherError) do
      aes_decrypt(enc, key, PAD_NOPAD)
    end
    
  end
end
