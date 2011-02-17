# encoding: utf-8

require 'helper'
require 'securerandom'

class TestRcsCommon < Test::Unit::TestCase
  def test_pascalize
    source = "ciao"
    #            length             c            i            a            o           null
    dest = "\x0a\x00\x00\x00" + "\x63\x00" + "\x69\x00" + "\x61\x00" + "\x6f\x00" + "\x00\x00"

    pascal = source.pascalize

    assert_equal dest, pascal
    # this is a stream of bytes represented as ASCII
    assert_equal pascal.encoding.to_s, 'ASCII-8BIT'
  end

  def test_unpascalize
    #              length             c            i            a            o           null
    source = "\x0a\x00\x00\x00" + "\x63\x00" + "\x69\x00" + "\x61\x00" + "\x6f\x00" + "\x00\x00"
    dest = "ciao"

    pascal = source.unpascalize
    
    assert_equal dest, pascal
    assert_equal dest.encoding, pascal.encoding
  end

  def test_pascalize_unicode
    source = "スパイ"
    #            length             ス            パ            イ         null
    dest = "\x08\x00\x00\x00" + "\xb9\x30" + "\xd1\x30" + "\xa4\x30" + "\x00\x00"

    pascal = source.pascalize

    # we have to force the comparison in ASCII-8BIT otherwise the
    # assert_equal function will complain about invalid UTF-8 sequence
    assert_equal dest.force_encoding('ASCII-8BIT'), pascal.force_encoding('ASCII-8BIT')
  end

  def test_unpascalize_unicode
    #              length             ス            パ            イ         null
    source = "\x08\x00\x00\x00" + "\xb9\x30" + "\xd1\x30" + "\xa4\x30" + "\x00\x00"
    dest = "スパイ"

    pascal = source.unpascalize
    
    assert_equal dest, pascal
  end

  def test_pascalize_null
    source = ""
    #            length            null
    dest = "\x02\x00\x00\x00" + "\x00\x00"

    assert_equal dest, source.pascalize
  end

  def test_unpascalize_null
    #              length            null
    source = "\x0a\x00\x00\x00" + "\x00\x00"
    dest = ""

    assert_equal dest, source.unpascalize
  end
  
  def test_unpascalize_multi
    multi_source = "\x0a\x00\x00\x00c\x00i\x00a\x00o\x00\x00\x00" +
                   "\x0a\x00\x00\x00m\x00i\x00a\x00o\x00\x00\x00" +
                   "\x08\x00\x00\x00b\x00a\x00o\x00\x00\x00"
    multi_dest = ["ciao", "miao", "bao"]

    assert_equal multi_dest, multi_source.unpascalize_ary
  end

end
