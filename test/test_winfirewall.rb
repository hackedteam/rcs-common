# encoding: utf-8

require 'helper'
require 'securerandom'

require 'rcs-common/winfirewall'

class WinFirewallTest < Test::Unit::TestCase
  def subject
    self.class.subject
  end

  def self.subject
    RCS::Common::WinFirewall
  end

  if subject.exists?
    def call(command)
      subject::Advfirewall.call(command)
    end

    def test_status
      call("set currentprofile state off")
      assert_equal(subject.status, :off)

      call("set currentprofile state on")
      assert_equal(subject.status, :on)
    end

    def test_block_inbound
      call("set currentprofile firewallpolicy allowinbound,allowoutbound")
      assert_equal(subject.block_inbound?, false)

      call("set currentprofile firewallpolicy blockinboundalways,allowoutbound")
      assert_equal(subject.block_inbound?, true)

      call("set currentprofile firewallpolicy blockinbound,allowoutbound")
      assert_equal(subject.block_inbound?, true)
    end

    def test_add_rule_and_del_rule
      rule_name = "test_rule_#{rand(1E10)}"
      subject.add_rule(action: :allow, direction: :in, name: rule_name, local_port: 80, remote_ip: %w[LocalSubnet 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16], protocol: :tcp)
      assert_equal(call("firewall show rule name=#{rule_name}").has_separator?, true)
      subject.del_rule(rule_name)
      assert_equal(call("firewall show rule name=#{rule_name}").has_separator?, false)
    end

    def test_dns_resolution
      rule_name = "test_rule_#{rand(1E10)}"
      subject.add_rule(action: :allow, direction: :in, name: rule_name, remote_ip: "wikipedia.org", protocol: :tcp)
      resp = call("firewall show rule name=#{rule_name}")
      assert_equal(resp.include?('208.80.154.224'), true)
      subject.del_rule(rule_name)

      assert_raise { subject.add_rule(action: :allow, direction: :in, name: rule_name, remote_ip: "wikipedia.org.x.x.x", protocol: :tcp) }
      assert_equal(call("firewall show rule name=#{rule_name}").has_separator?, false)
    end

    def test_del_missing_rule
      assert_nothing_raised { subject.del_rule("#{rand(1E30)}") }
    end
  end
end
