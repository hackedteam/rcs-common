# encoding: utf-8

require 'helper'
require 'securerandom'

require 'rcs-common/winfirewall'

# The #undescore method is added by active_support/core_ext/string/inflections
# Here's a very simple implementation
class String
  def underscore
    word = self.to_s.dup
    word.gsub!(/::/, '/')
    # word.gsub!(/(?:([A-Za-z\d])|^)(#{inflections.acronym_regex})(?=\b|[^a-z])/) { "#{$1}#{$1 && '_'}#{$2.downcase}" }
    word.gsub!(/([A-Z\d]+)([A-Z][a-z])/,'\1_\2')
    word.gsub!(/([a-z\d])([A-Z])/,'\1_\2')
    word.gsub!("-", "_")
    word.downcase!
    word
  end
end

class WinFirewallTest < Test::Unit::TestCase
  def subject
    @subject ||= RCS::Common::WinFirewall
  end

  def stub_advfirewall_and_return(filepath)
    RCS::Common::WinFirewall::Advfirewall.__send__(:define_singleton_method, :call) do |cmd|
      stubbed_resp = File.read(File.expand_path("../fixtures/advfirewall/#{filepath}", __FILE__))
      RCS::Common::WinFirewall::AdvfirewallResponse.new(stubbed_resp)
    end

    # Stub #resolve_addresses! => Do not raise error when DNS
    # cannot be resolved
    eval 'class RCS::Common::WinFirewall::Rule; def resolve_addresses!; end; end'
  end

  def test_status_on
    stub_advfirewall_and_return("show_currentprofile_state_on")
    assert_equal(subject.status, :on)
  end

  def test_status_off
    stub_advfirewall_and_return("show_currentprofile_state_off")
    assert_equal(subject.status, :off)
  end

  def test_successfully_change_status
    stub_advfirewall_and_return("command_ok")
    assert_block { subject.status = :on }
    assert_block { subject.status = :off }
  end

  def test_wrong_change_status
    stub_advfirewall_and_return("command_ok")
    assert_raise { subject.status = :invalid_value }

    stub_advfirewall_and_return("command_err")
    assert_raise { subject.status = :on }
  end

  def test_rules_size
    stub_advfirewall_and_return("firewall_show_rule_name_all")
    assert_equal(subject.rules.size, 306)
  end

  def test_rules_parsing
    stub_advfirewall_and_return("firewall_show_rule_name_all")

    rule = subject.rules.first
    expected_attributes = {
      :enabled=>:yes,
      :protocol=>:udp,
      :profiles=>:public,
      :grouping=>"RCS Firewall Rules",
      :direction=>:in,
      :local_ip=>:any,
      :remote_ip=>:any,
      :local_port=>:any,
      :remote_port=>:any,
      :edge_traversal=>:defer_to_user,
      :action=>:allow,
      :name=>"Ruby interpreter (CUI) 2.0.0p247 [i386-mingw32]"
    }
    assert_equal(rule.attributes, expected_attributes)

    rule = subject.rules.find { |rule| rule.name == "Media Center Extenders - WMDRM-ND/RTP/RTCP (UDP-In)" }
    expected_attributes = {
      :enabled=>:no,
      :protocol=>:udp,
      :profiles=>[:domain, :private, :public],
      :grouping=>"Media Center Extenders",
      :name=>"Media Center Extenders - WMDRM-ND/RTP/RTCP (UDP-In)",
      :direction=>:in,
      :local_ip=>:any,
      :remote_ip=>"LocalSubnet",
      :local_port=>[7777,7778,7779,7780,7781,5004,5005,50004,50005,50006,50007,50008,50009,50010,50011,50012,50013],
      :remote_port=>:any,
      :edge_traversal=>:no,
      :action=>:allow
    }
    assert_equal(rule.attributes, expected_attributes)
  end

  def test_rule_del
    stub_advfirewall_and_return("firewall_show_rule_name_all")
    rule = subject.rules.first

    stub_advfirewall_and_return("firewall_delete_rule_ok")
    assert_equal(rule.del, 3)

    stub_advfirewall_and_return("firewall_delete_rule_no_match")
    assert_equal(rule.del, 0)

    stub_advfirewall_and_return("command_err")
    assert_raise { rule.del }
  end
end
