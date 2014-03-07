require 'helper'

class TestRcsCommon < Test::Unit::TestCase

  def test_mime_cod
    mime = RCS::MimeType::get('test.cod')
    expected = 'application/vnd.rim.cod'
    assert_equal expected, mime
  end

  def test_mime_jad
    mime = RCS::MimeType::get('test.jad')
    expected = 'text/vnd.sun.j2me.app-descriptor'
    assert_equal expected, mime
  end

  def test_mime_jnlp
    mime = RCS::MimeType::get('test.jnlp')
    expected = 'application/x-java-jnlp-file'
    assert_equal expected, mime
  end

  def test_mime_cab
    mime = RCS::MimeType::get('test.cab')
    #expected = 'application/vnd.ms-cab-compressed'
    # fucking IE mobile not understanding the real mime type
    expected = 'binary/octet-stream'
    assert_equal expected, mime
  end

  def test_mime_apk
    mime = RCS::MimeType::get('test.apk')
    expected = 'application/vnd.android.package-archive'
    assert_equal expected, mime
  end

  def test_mime_exe
    mime = RCS::MimeType::get('test.exe')
    expected = 'application/x-msdos-program'
    assert_equal expected, mime
  end

  def test_mime_unknown
    mime = RCS::MimeType::get('test.unknown')
    expected = 'binary/octet-stream'
    assert_equal expected, mime
  end

end
