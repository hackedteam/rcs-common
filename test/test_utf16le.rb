# encoding: utf-8

require 'helper'

class StringIOTest < Test::Unit::TestCase

  def test_correct_string
    str = "aabbccdd"
    bin = str.to_utf16le_binary_null
    stream = StringIO.new bin
    dst = stream.read_utf16le_string
    assert_equal str, dst.utf16le_to_utf8
  end

  def test_unicode_string
    str = "こんにちは世界"
    bin = str.to_utf16le_binary_null
    stream = StringIO.new bin
    dst = stream.read_utf16le_string
    assert_equal str, dst.utf16le_to_utf8
  end


  def test_zero_string
    str = "\0".encode('UTF-16LE')
    stream = StringIO.new str
    dst = stream.read_utf16le_string
    assert_equal '', dst.utf16le_to_utf8
  end

  def test_string_too_short
    str = "\0"
    stream = StringIO.new str
    dst = stream.read_utf16le_string
    assert_equal nil, dst
  end

  def test_misaligned_string
    str = "aa\0"
    stream = StringIO.new str
    dst = stream.read_utf16le_string
    assert_equal nil, dst
  end
  
  def test_string_not_terminated
    str = "aabbcc"
    bin = str.to_utf16le_binary_null
    stream = StringIO.new bin
    dst = stream.read_utf16le_string
    assert_equal str, dst.utf16le_to_utf8
  end

  def test_double_string
    expected = "aabbc"
    str = expected.to_utf16le_binary_null + "ddeef".to_utf16le_binary
    stream = StringIO.new str
    dst = stream.read_utf16le_string
    assert_equal expected, dst.utf16le_to_utf8
  end


end