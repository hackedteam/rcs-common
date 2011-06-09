require 'helper'

module RCS

# dirty hack to fake the trace function
# re-open the class and override the method
class EvidenceManager
  def trace(a, b)
  end
end

class TestEvidenceManager < Test::Unit::TestCase

  def setup
    @instance = "test-instance"
    EvidenceManager.instance.create_repository @instance
    assert_true File.exist?(EvidenceManager::REPO_DIR + '/' + @instance)
    @session = {:bid => '141178',
               :build => 'test-build',
               :instance => @instance,
               :subtype => 'test-subtype'}

    @ident = [2011010101, 'test-user', 'test-device', 'test-source']
    @now = Time.now.getutc.to_i
  end

  def teardown
    File.delete(EvidenceManager::REPO_DIR + '/' + @instance) if File.exist?(EvidenceManager::REPO_DIR + '/' + @instance)
    Dir.delete(EvidenceManager::REPO_DIR) if File.directory?(EvidenceManager::REPO_DIR)
  end

  def test_sync_start
    EvidenceManager.instance.sync_start @session, *@ident, @now

    info = EvidenceManager.instance.instance_info @session[:instance]
   
    assert_equal @session[:bid], info['bid']
    assert_equal @session[:build], info['build']
    assert_equal @session[:instance], info['instance']
    assert_equal @session[:subtype], info['subtype']
    assert_equal @ident[0], info['version']
    assert_equal @ident[1], info['user']
    assert_equal @ident[2], info['device']
    assert_equal @ident[3], info['source']
    assert_equal @now.to_i, info['sync_time']
    assert_equal EvidenceManager::SYNC_IN_PROGRESS, info['sync_status']
  end

  def test_sync_timeout_after_start
    EvidenceManager.instance.sync_start @session, *@ident, @now
    EvidenceManager.instance.sync_timeout @session
    info = EvidenceManager.instance.instance_info @session[:instance]
    assert_equal EvidenceManager::SYNC_TIMEOUTED, info['sync_status']
  end

  def test_sync_timeout_after_end
    EvidenceManager.instance.sync_start @session, *@ident, @now
    EvidenceManager.instance.sync_end @session
    EvidenceManager.instance.sync_timeout @session
    info = EvidenceManager.instance.instance_info @session[:instance]
    assert_equal EvidenceManager::SYNC_IDLE, info['sync_status']
  end

  def test_sync_timeout_all
    EvidenceManager.instance.sync_start @session, *@ident, @now
    EvidenceManager.instance.sync_timeout_all
    info = EvidenceManager.instance.instance_info @session[:instance]
    assert_equal EvidenceManager::SYNC_TIMEOUTED, info['sync_status']
  end

  def test_sync_timeout_all_idle
    EvidenceManager.instance.sync_start @session, *@ident, @now
    EvidenceManager.instance.sync_end @session
    EvidenceManager.instance.sync_timeout_all
    info = EvidenceManager.instance.instance_info @session[:instance]
    assert_equal EvidenceManager::SYNC_IDLE, info['sync_status']
  end

  def test_sync_end
    EvidenceManager.instance.sync_start @session, *@ident, @now
    EvidenceManager.instance.sync_end @session
    info = EvidenceManager.instance.instance_info @session[:instance]
    assert_equal EvidenceManager::SYNC_IDLE, info['sync_status']
  end

  def test_sync_not_existent
    File.delete(EvidenceManager::REPO_DIR + '/' + @instance)
    EvidenceManager.instance.sync_end @session
    info = EvidenceManager.instance.instance_info @session[:instance]
    assert_nil info
  end

  def test_sync_start_start
    EvidenceManager.instance.sync_start @session, *@ident, @now
    EvidenceManager.instance.sync_start @session, *@ident, @now
    info = EvidenceManager.instance.instance_info @session[:instance]
    assert_equal EvidenceManager::SYNC_IN_PROGRESS, info['sync_status']
  end

  def test_evidence
    evidence = "test-evidence"
    EvidenceManager.instance.sync_start @session, *@ident, @now
    # insert two fake evidences
    id1 = EvidenceManager.instance.store_evidence @session, evidence.length, evidence
    id2 = EvidenceManager.instance.store_evidence @session, evidence.length, evidence
    info = EvidenceManager.instance.evidence_info @session[:instance]
    assert_equal evidence.length, info[0].first
    assert_equal evidence.length, info[1].first
    assert_equal 2, info.length
    assert_true id1 > 0
    assert_true id2 > 0
    assert_true id2 > id1
  end

end

end #RCS::
