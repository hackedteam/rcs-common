require "helper"

class TestTime < Test::Unit::TestCase
  
  def setup
    @high_memory = "\x90\xd9\xcb\x01"
    @low_memory = "\x50\x67\xe0\x63"
    @high = 0x01cbd990
    @low = 0x63e06750
  end
  
  def test_from_filetime
    assert_equal '2011-03-03 10:47:28 UTC', Time.from_filetime(@high, @low).to_s
  end
  
  def test_from_filetime_has_millisec
    assert_equal Time.from_filetime(@high, @low).usec, 436001
  end
  
  def test_unpack_from_memory
    h = @high_memory.unpack('I').shift
    l = @low_memory.unpack('I').shift
    assert_equal '2011-03-03 10:47:28 UTC', Time.from_filetime(h, l).to_s
  end

  def test_to_filetime
    date = Time.parse('2011-03-03 10:47:28 UTC')
    date = Time.at(date.to_i, 436001)

    filetime = date.to_filetime.pack('L*')

    memory = (@low_memory + @high_memory).force_encoding('ASCII-8BIT')

    assert_equal memory, filetime
  end

  def test_epoch
    epoch = Time.from_filetime(0, 0)

    assert_equal '1601-01-01 00:00:00 UTC', epoch.to_s
  end

  def test_from_and_to
    now = Time.now.getutc

    buff = StringIO.new

    buff.write now.to_filetime.pack('L*')
    buff.rewind
    low, high = buff.read(8).unpack('L*')
    check = Time.from_filetime(high, low)

    # we explicitly ignore the usec, msec part
    assert_equal now.to_s, check.to_s
  end
end
