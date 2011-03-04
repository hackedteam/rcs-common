require "helper"

class TestSingleton
  include Singleton
  extend FlatSingleton

  def test
    return 'flat test succeeded'
  end
end

class FlatSingletonTest < Test::Unit::TestCase

  def test_flat_singleton
    assert_equal 'flat test succeeded', TestSingleton.test
  end
end