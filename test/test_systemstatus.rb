require 'helper'

module RCS

class TestStatus < Test::Unit::TestCase

  def test_disk
    disk = SystemStatus.disk_free

    # it should return a number
    assert_kind_of Fixnum, disk
    # it is a percentage
    assert_equal true, (disk >= 0 and disk <= 100)
  end

  def test_load
    load = SystemStatus.cpu_load

    # it should return a number
    assert_kind_of Fixnum, load
    # it could be even greater than 100 on high load
    assert_equal true, (load >= 0)
  end

  def test_process_cpu
    cpu = SystemStatus.my_cpu_load('test')

    # it should return a number
    assert_kind_of Fixnum, cpu
    # it is a percentage
    assert_equal true, (cpu >= 0 and cpu <= 100)
  end
end

end #RCS::
