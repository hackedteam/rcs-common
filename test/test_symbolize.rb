require 'helper'

class TestRcsCommon < Test::Unit::TestCase

  def test_symbolize
    src = {'one' => 1, 'two' => 2}
    dst = {:one => 1, :two => 2}

    res = src.symbolize

    assert_equal dst, res
  end

end
