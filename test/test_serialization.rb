require "helper"

class TestSerialization < Test::Unit::TestCase

  # Fake test
  def test_generate_prefix
    type = 0xff
    size = 0xaabbcc

    assert_equal "\xCC\xBB\xAA\xFF", RCS::Serialization::prefix(type, size)
  end

  def test_decode_prefix
    type, size = RCS::Serialization::decode_prefix("\xCC\xBB\xAA\xFF")

    assert_equal type, 0xff
    assert_equal size, 0xaabbcc
  end

end