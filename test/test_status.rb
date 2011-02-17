require 'helper'

module RCS
module Collector

# dirty hack to fake the trace function
# re-open the class and override the method
class Status
  def trace(a, b)
  end
end

class TestStatus < Test::Unit::TestCase

  def test_disk
    disk = Status.disk_free

    # it should return a number
    assert_kind_of Fixnum, disk
    # it is a percentage
    assert_true (disk >= 0 and disk <= 100)
  end

  def test_load
    load = Status.cpu_load

    # it should return a number
    assert_kind_of Fixnum, load
    # it could be even greater than 100 on high load
    assert_true (load >= 0)
  end

  def test_process_cpu
    cpu = Status.my_cpu_load

    # it should return a number
    assert_kind_of Fixnum, cpu
    # it is a percentage
    assert_true (cpu >= 0 and cpu <= 100)
  end
end

end #Collector::
end #RCS::
