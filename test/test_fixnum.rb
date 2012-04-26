require "helper"

class FixnumTest < Test::Unit::TestCase

  def test_byte
    assert_equal "1023 B", 1023.to_s_bytes
    assert_equal "999 B", 999.to_s_bytes(10)
  end
  
  def test_kilo
    assert_equal "1.0 KiB", (2**10).to_s_bytes
    assert_equal "1.02 kB", (2**10).to_s_bytes(10)
    assert_equal "1.0 kB", (10**3).to_s_bytes(10)
  end

  def test_mega
    assert_equal "1.0 MiB", (2**20).to_s_bytes
    assert_equal "1.05 MB", (2**20).to_s_bytes(10)
    assert_equal "1.0 MB", (10**6).to_s_bytes(10)
  end

  def test_giga
    assert_equal "1.0 GiB", (2**30).to_s_bytes
    assert_equal "1.07 GB", (2**30).to_s_bytes(10)
    assert_equal "1.0 GB", (10**9).to_s_bytes(10)
  end

  def test_tera
    assert_equal "1.0 TiB", (2**40).to_s_bytes
    assert_equal "1.1 TB", (2**40).to_s_bytes(10)
    assert_equal "1.0 TB", (10**12).to_s_bytes(10)
  end


end