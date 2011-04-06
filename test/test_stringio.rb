require 'helper'

class StringIOTest < Test::Unit::TestCase

  # Fake test
  def test_correct_string
    str = "aabbccdd\0".encode('UTF-16LE')
    stream = StringIO.new str
    
    dst = stream.read_utf16_string
    assert_equal str, dst.force_encoding('UTF-16LE')
  end

  def test_zero_string
    str = "\0".encode('UTF-16LE')
    stream = StringIO.new str

    dst = stream.read_utf16_string
    assert_equal str, dst.force_encoding('UTF-16LE')
  end

  def test_string_too_short
    str = "\0"
    stream = StringIO.new str

    dst = stream.read_utf16_string
    assert_equal nil, dst
  end

  def test_misaligned_string
    str = "aa\0"
    stream = StringIO.new str

    dst = stream.read_utf16_string
    assert_equal nil, dst
  end
  
  def test_string_not_terminated
    str = "aabbcc".encode('UTF-16LE')
    
    stream = StringIO.new str
    dst = stream.read_utf16_string
    assert_equal str, dst.force_encoding('UTF-16LE')
  end

  def test_double_string
    expected = "aabbc\0".encode('UTF-16LE')
    str = expected + "ddeef".encode('UTF-16LE')

    stream = StringIO.new str
    dst = stream.read_utf16_string
    assert_equal expected, dst.force_encoding('UTF-16LE')
  end

  def test_1
    
  end
end