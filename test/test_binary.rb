require "test/unit"
require 'securerandom'

class BinaryPatchTest < Test::Unit::TestCase

  def test_string
    input = "string to be modified"
    output = "string modified"

    input.binary_patch "to be ", ""

    assert_equal output, input
  end

  def test_binary
    input = SecureRandom.random_bytes(16)
    search = input.slice(0..3)
    output = "1234" + input[4..-1]

    input.binary_patch search, "1234"

    assert_equal output, input
  end

  def test_binary_with_regex
    input = SecureRandom.random_bytes(16)
    search = input.slice(0..3)
    output = '\&$1' + input[4..-1]

    input.binary_patch search, '\&$1'

    assert_equal output, input
  end

  def test_not_found
    input = "ciao"

    assert_raise MatchNotFound do
      input.binary_patch "miao", "bau"
    end
  end

end