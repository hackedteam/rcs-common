# encoding: utf-8

require "test/unit"

class SanitizeTest < Test::Unit::TestCase

  def test_binary
    input = "keep this and not those \x90 \x91 \x92"
    output = 'keep this and not those '
    assert_equal output, input.remove_invalid_chars
  end

  def test_punctuation
    input = "keep all .,;:!? and also @#%&*()[]{}\"'\\/+="
    output = "keep all .,;:!? and also @#%&*()[]{}\"'\\/+="
    assert_equal output, input.remove_invalid_chars
  end

  def test_specials
    input = "keep them \$ ^ |"
    output = "keep them \$ ^ |"
    assert_equal output, input.remove_invalid_chars
  end

  def test_strip_html_tags
    input = "Strip <i>these</i> tags!"
    output = "Strip these tags!"
    assert_equal output, input.strip_html_tags

    input = "<b>Bold</b> no more!  <a href='more.html'>See more here</a>..."
    output = "Bold no more!  See more here..."
    assert_equal output, input.strip_html_tags

    input = "<div id='top-bar'>Welcome to my website!</div>"
    output = "Welcome to my website!"
    assert_equal output, input.strip_html_tags
  end


end