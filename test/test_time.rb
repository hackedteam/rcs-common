require "helper"

class TestTime < Test::Unit::TestCase
  
  def test_filetime
    t = Time.now
    assert_equal Time.from_filetime(*t.to_filetime).to_s, t.to_s
  end
  
end
