require "helper"

class TestTime < Test::Unit::TestCase
  
  def setup
    @high_memory = "\x90\xd9\xcb\x01"
    @low_memory = "\x40\x67\xe0\x63"
    @high = 0x01cbd990
    @low = 0x63e06740
  end
  
  def test_from_filetime
    assert_equal '2011-03-03 11:47:28 +0100', Time.from_filetime(@high, @low).to_s
  end
  
  def test_from_filetime_has_millisec
    assert_equal Time.from_filetime(@high, @low).usec, 436000
  end
  
  def test_unpack_from_memory
    h = @high_memory.unpack('I').shift
    l = @low_memory.unpack('I').shift
    assert_equal '2011-03-03 11:47:28 +0100', Time.from_filetime(h, l).to_s
  end
end
