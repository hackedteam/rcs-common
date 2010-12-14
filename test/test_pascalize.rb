require 'helper'

class TestRcsCommon < Test::Unit::TestCase
  def test_pascalize
    source = "ciao"
    #            length             c            i            a            o           null
    dest = "\x0a\x00\x00\x00" + "\x63\x00" + "\x69\x00" + "\x61\x00" + "\x6f\x00" + "\x00\x00"

    assert_equal dest, source.pascalize
  end

  def test_unpascalize
    #              length             c            i            a            o           null
    source = "\x0a\x00\x00\x00" + "\x63\x00" + "\x69\x00" + "\x61\x00" + "\x6f\x00" + "\x00\x00"
    dest = "ciao"

    assert_equal dest, source.unpascalize
  end

  def test_unpascalize_multi
    multi_source = "\x0a\x00\x00\x00c\x00i\x00a\x00o\x00\x00\x00" + "\x0a\x00\x00\x00m\x00i\x00a\x00o\x00\x00\x00" + "\x08\x00\x00\x00b\x00a\x00o\x00\x00\x00"
    multi_dest = ["ciao", "miao", "bao"]

    assert_equal multi_dest, multi_source.unpascalize_ary
  end
end
