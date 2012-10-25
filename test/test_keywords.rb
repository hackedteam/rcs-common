# encoding: utf-8

require 'helper'
require 'securerandom'

class KeywordsTest < Test::Unit::TestCase

  def test_dont_modify_source
    input = "abc 123 : 456 + @ pippo"
    source = input.dup
    output = ['123', '456', 'abc', 'pippo']
    assert_equal output, input.keywords
    assert_equal source, input
  end

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

  def test_marks
    input = "do you know me? of course!"
    output = ["course", "do", "know", "me", "of", "you"]
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

  def test_symbols
    input = "alor, ... + 10% +3946 / * alor@ht-ht {sid-55--55} [ht] (55%) A&F ht_ht <html>"
    output = ["10", "3946", "55", "a", "alor", "f", "ht", "html", "sid"]
    assert_equal output, input.keywords
  end

  def test_utf8_symbols
    input = "ス alor, ... + 10% +3946 / * alor@ht-ht {sid-55--55} [ht] (55%) A&F ht_ht <html>"
    output = ["10", "3946", "55", "a", "alor", "f", "ht", "html", "sid", "ス"]
    assert_equal output, input.keywords
  end

  def test_tweet
    input = "this is cool :) #coolesthing"
    output = ["cool", "coolesthing", "is", "this"]
    assert_equal output, input.keywords
  end

  def test_ascii
    input = "abc def".force_encoding("ASCII-8BIT")
    output = ["abc", "def"]
    assert_equal output, input.keywords
  end

  def test_binary
    input = "keep " + SecureRandom.random_bytes(16)
    output = ['keep']
    assert_equal output, output & input.keywords
  end

  def test_binary_special
    input = "\x6b\x65\x65\x70\x20\xf1\xb5\xfb\xc0\x55\x22\x23\xee\x25\xca\xd9\xde\x02\xef\x0d\xf1"
    output = ['keep']
    assert_equal output, output & input.keywords
  end


  def test_avoid_word_too_long
    input = "how do we handle encoded binary like this dGhpcyBpcyBhIHdvcmQgdG9vIGxvbmcK?"
    output = ["binary", "do", "encoded", "handle", "how", "like", "this", "we"]
    assert_equal output, input.keywords
  end

  def test_invalid_chars
    input = "Menu \x95 U .'7\x95--;,"
    output = ['7', 'menu', 'u']
    assert_equal output, input.keywords
  end

  def test_real_ocr
    input = "Menu \x95 U .'7\x95--;, '.,1 ID 10:35\ni 4 lli 1 - 1/.\nEll rat\nIP' ,\nContacts Messaging Web\nGo\nGallery Calendar Mail\nStore Vi eos Music p ayer\n\\ li\nSearch Maps Settings\nCt \x97\n\x97"
    output = ["1","10","35","4","7","ayer","calendar","contacts","ct","ell","eos","gallery","go","i","id","ip","li","lli","mail","maps","menu","messaging","music","p","rat","search","settings","store","u","vi","web"]
    assert_equal output, input.keywords
  end

end
