require "helper"
require "rcs-common/evidence"
module RCS

  # TODO: implement more test cases for Evidence class
class TestEvidence < Test::Unit::TestCase
  
  # Called before every test method runs. Can be used
  # to set up fixture information.
  def setup
    @key = ["000102030405060708090a0b0c0d0e0f"].pack('H*')
    @info = { :device_id => "test-device", :user_id => "test-user", :source_id => "127.0.0.1" }
  end
  
  # Called after every test method runs. Can be used to tear
  # down fixture information.
  
  def teardown
    # Do nothing
  end
  
  # TODO: this test is not really a good one ... tests both generation and deserialization of evidence :(
  def test_generate
    piece = RCS::Evidence.new(@key).generate(:DEVICE, @info)
    evidence = RCS::Evidence.new(@key).deserialize(piece.binary)
    
    assert_equal piece.content.force_encoding('UTF-16LE').encode('UTF-8'), evidence[0].content.force_encoding('UTF-16LE').encode('UTF-8')
  end
  
  def test_align_to_block_len
    evidence = RCS::Evidence.new(@key)
    assert_equal(0, evidence.align_to_block_len(0))
    assert_equal(16, evidence.align_to_block_len(15))
    assert_equal(16, evidence.align_to_block_len(16))
    assert_equal(32, evidence.align_to_block_len(17))
  end
  
  def test_encrypt
    evidence = RCS::Evidence.new(@key)
    test_string = ['00112233445566778899aabbccddeeff'].pack('H*')
    assert_equal('69c4e0d86a7b0430d8cdb78070b4c55a', evidence.encrypt(test_string).unpack('H*').shift)
  end
  
  def test_decrypt
    evidence = RCS::Evidence.new(@key)
    test_string = ['69c4e0d86a7b0430d8cdb78070b4c55a'].pack('H*')
    assert_equal('00112233445566778899aabbccddeeff', evidence.decrypt(test_string).unpack('H*').shift)
  end

end

end # RCS::
