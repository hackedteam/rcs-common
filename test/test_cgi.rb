require 'helper'

class URITest < Test::Unit::TestCase

  def test_hash_to_uri_query
    h = {'q' => 'pippo', 'filter' => 'pluto', :symbol => 'paperino'}
    assert_equal "?q=pippo&filter=pluto&symbol=paperino", CGI.encode_query(h)
  end

  def test_hash_with_special_chars_to_uri_query
    h = {'q' => 'pippo pluto paperino'}
    assert_equal "?q=pippo+pluto+paperino", CGI.encode_query(h)
  end
end