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
end