require 'helper'

class TestRcsCommon < Test::Unit::TestCase

  include RCS::Tracer

  def test_trace_init_raise

    # must fail since it does not find trace.yaml
    assert_raise RuntimeError do
      trace_init(Dir.pwd)
    end

  end

  def test_trace_init_ok

    # must succeed since the trace.yaml is specified
    assert_nothing_raised do
      trace_init(Dir.pwd, Dir.pwd + "/lib/rcs-common/trace.yaml")
    end

  end

end
