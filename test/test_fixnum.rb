require "helper"

class FixnumTest < Test::Unit::TestCase

  def test_kilo
    assert_equal "1.0 KiB", (2**10).to_s_bytes
  end

  def test_mega
    assert_equal "1.0 MiB", (2**20).to_s_bytes
  end

  def test_giga
    assert_equal "1.0 GiB", (2**30).to_s_bytes
  end

  def test_tera
    assert_equal "1.0 TiB", (2**40).to_s_bytes
  end


end