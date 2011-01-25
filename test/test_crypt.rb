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

    # padding is ON by default, disable it
    enc = aes_encrypt(clear, key, PAD_NOPAD)

    # must be exactly the same size
    assert_true enc.length == clear.length

    dec = aes_decrypt(enc, key, PAD_NOPAD)

    assert_equal clear, dec
  end

  def test_crypt_not_multiple_of_block_size_no_pad

    clear = SecureRandom.random_bytes(19)
    key = Digest::MD5.digest "4yeN5zu0+il3Jtcb5a1sBcAdjYFcsD9z"

    # padding is ON by default, disable it
    assert_raise(OpenSSL::Cipher::CipherError) do
      aes_encrypt(clear, key, PAD_NOPAD)
    end
  end

  def test_crypt_wrong_padding

    clear = SecureRandom.random_bytes(16)
    key = Digest::MD5.digest "4yeN5zu0+il3Jtcb5a1sBcAdjYFcsD9z"

    # padding is ON by default, disable it
    enc = aes_encrypt(clear, key, PAD_NOPAD)

    # must be exactly the same size
    assert_true enc.length == clear.length

    assert_raise(OpenSSL::Cipher::CipherError) do
      aes_decrypt(enc, key)
    end
  end

  def test_crypt_integrity
    clear = SecureRandom.random_bytes(21)
    key = Digest::MD5.digest "secret"

    enc = aes_encrypt_integrity(clear, key)
    dec = aes_decrypt(enc, key)

    # extract the sha1 integrity check
    check = dec.slice!(dec.length - Digest::SHA1.new.digest_length, dec.length)

    assert_equal clear, dec
    assert_equal check, Digest::SHA1.digest(dec)
  end

  def test_decrypt_integrity
    clear = SecureRandom.random_bytes(21)
    key = Digest::MD5.digest "secret"

    clear_check = clear + Digest::SHA1.digest(clear)

    enc = aes_encrypt(clear_check, key)
    dec = ""
    assert_nothing_raised do
      dec = aes_decrypt_integrity(enc, key)
    end
    assert_equal clear, dec
  end

  def test_decrypt_integrity_fail
    clear = SecureRandom.random_bytes(21)
    key = Digest::MD5.digest "secret"

    # fake sha1 check
    clear_check = clear + SecureRandom.random_bytes(20)
    enc = aes_encrypt(clear_check, key)

    # this will fail to validate the sha1
    assert_raise do
      aes_decrypt_integrity(enc, key)
    end
  end

end
