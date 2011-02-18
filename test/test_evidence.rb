require "helper"

module RCS

class TestEvidence < Test::Unit::TestCase
  
  # Called before every test method runs. Can be used
  # to set up fixture information.
  def setup
    @key = 'Ez2vdMwu6VNQxsSj2OmUhbOzoPwsgJTP'
    @info = { :device_id => "test-device", :user_id => "test-user", :source_id => "127.0.0.1" }
  end
  
  # Called after every test method runs. Can be used to tear
  # down fixture information.
  
  def teardown
    # Do nothing
  end
  
  # Fake test
  def test_generate
    piece = RCS::Evidence.new(@key, @info).generate(:DEVICE)
    evidence = RCS::Evidence.new(@key).deserialize(piece.binary)
      
    assert_equal piece.content.force_encoding('UTF-16LE').encode('UTF-8'), evidence.content
    assert_equal piece.binary, evidence.binary
  end
  
end

end # RCS::
