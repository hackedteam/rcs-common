# encoding: utf-8

require 'helper'
require 'rcs-common/path_utils'

class PathutilsTest < Test::Unit::TestCase

  class IncludePathUtils; include RCS::Common::PathUtils; end

	def setup
    @subject = IncludePathUtils.new
  end

  def test_require_release
    assert_raise { @subject.require_release 'folder/file' }
    assert_raise { @subject.require_release 'rcsdb/folder/folder/file' }

    assert_respond_to(Object.new, :require_release)
    assert_respond_to(self, :require_release)

    assert_raise(LoadError) { @subject.require_release 'rcs-project/file1' }
    assert_raise(LoadError) { @subject.require_release 'rcs-project-release/file1' }
  end
end
