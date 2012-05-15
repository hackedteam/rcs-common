require "helper"

module RCS


class StatsManager < Stats
  def initialize
    @sections = {:minutes => 0, :hours => 60, :days => 24, :weeks => 7}
    @template = {count: 0}
    super
  end
end

class TestStats < Test::Unit::TestCase
  
  def setup

  end
  
  def test_single_minute
    statistic = StatsManager.new
    statistic.add count: 1
    stats = statistic.stats

    assert_equal 1, stats[:total][:count]
    assert_equal 1, stats[:minutes][:last][0][:count]
    assert_equal 1, stats[:hours][:last][0][:count]
    assert_equal 1, stats[:days][:last][0][:count]
    assert_equal 1, stats[:weeks][:last][0][:count]
  end

  def test_two_minute
    statistic = StatsManager.new
    statistic.add count: 1
    statistic.calculate
    statistic.add count: 1
    stats = statistic.stats

    assert_equal 2, stats[:total][:count]
    assert_equal 1, stats[:minutes][:last][0][:count]
    assert_equal 2, stats[:hours][:last][0][:count]
    assert_equal 2, stats[:days][:last][0][:count]
    assert_equal 2, stats[:weeks][:last][0][:count]
  end

  def test_one_hour
    statistic = StatsManager.new

    1.upto(60) do
      statistic.add count: 1
      statistic.calculate
    end

    stats = statistic.stats

    assert_equal 60, stats[:total][:count]
    assert_equal 0, stats[:minutes][:last][0][:count]
    assert_equal 0, stats[:hours][:last][0][:count]
    assert_equal 60, stats[:days][:last][0][:count]
    assert_equal 60, stats[:weeks][:last][0][:count]

    assert_equal 1, stats[:minutes][:average][:count]
    assert_equal 60, stats[:hours][:average][:count]
  end

  def test_one_day
    statistic = StatsManager.new

    1.upto(1440) do
      statistic.add count: 1
      statistic.calculate
    end

    stats = statistic.stats

    assert_equal 1440, stats[:total][:count]
    assert_equal 0, stats[:minutes][:last][0][:count]
    assert_equal 0, stats[:hours][:last][0][:count]
    assert_equal 0, stats[:days][:last][0][:count]
    assert_equal 1440, stats[:weeks][:last][0][:count]

    assert_equal 1, stats[:minutes][:average][:count]
    assert_equal 60, stats[:hours][:average][:count]
    assert_equal 1440, stats[:days][:average][:count]
  end


end

end #RCS