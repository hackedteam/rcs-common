# encoding: utf-8

require 'helper'
require 'securerandom'

class KeywordsTest < Test::Unit::TestCase

  def test_strip
    input = "   ciao\n\t miao"
    output = ['ciao', 'miao']
    assert_equal output, input.keywords
  end

  def test_mixed_case
    input = "   CIAO miao ciao"
    output = ['ciao', 'miao']
    assert_equal output, input.keywords
  end

  def test_punctuation
    input = "ciao, miao. bau; ,pippo !pluto"
    output = ['bau', 'ciao', 'miao', 'pippo', 'pluto']
    assert_equal output, input.keywords
  end

  def test_email
    input = "a.ornaghi@hackingteam.it mail di alberto"
    output = ["a", "alberto", "di", "hackingteam", "it", "mail", "ornaghi"]
    assert_equal output, input.keywords
  end

  def test_duplicates
    input = "il mattino ha l'oro in bocca, il mattino ha l'oro in bocca"
    output = ["bocca", "ha", "il", "in", "l", "mattino", "oro"]
    assert_equal output, input.keywords
  end

  def test_utf8
    input = "スパイ alor, スパイ... "
    output = ['alor', 'スパイ']
    assert_equal output, input.keywords
  end

  def test_more_utf8
    input = "Il sØl, è bello!"
    output = ['bello', 'il', 'sØl', 'è']
    assert_equal output, input.keywords
  end

  def test_numbers
    input = "123 456 789"
    output = ['123', '456', '789']
    assert_equal output, input.keywords
  end

  def test_telephone_number
    input = "Il mio numero di telefono: +393480115642"
    output = ['393480115642', 'di', 'il', 'mio', 'numero', 'telefono']
    assert_equal output, input.keywords
  end

  def test_file_path
    input = "c:\\users\\alor\\documents\\secret\\plan.doc"
    output = ['alor', 'c', 'doc', 'documents', 'plan', 'secret', 'users']
    assert_equal output, input.keywords
  end


end
