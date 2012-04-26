require 'helper'

class TestRcsCommon < Test::Unit::TestCase

  def test_symbolize
    src = {'one' => 1, 'two' => 2}
    dst = {:one => 1, :two => 2}

    assert_equal dst, src.symbolize
  end

  def test_symbolize_mixed
    src = {'one' => 1, 'two' => 2, 1 => 'one', 2 => 'two'}
    dst = {:one => 1, :two => 2, 1 => 'one', 2 => 'two'}

    assert_equal dst, src.symbolize
  end


end
