#
# Author:: Tim Smith (<tsmith@chef.io>)
# Copyright:: 2020, Chef Software Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require "spec_helper"

describe Chef::Resource::ChefClientCron do
  let(:node) { Chef::Node.new }
  let(:events) { Chef::EventDispatch::Dispatcher.new }
  let(:run_context) { Chef::RunContext.new(node, {}, events) }
  let(:resource) { Chef::Resource::ChefClientCron.new("fakey_fakerton", run_context) }
  let(:provider) { resource.provider_for_action(:add) }

  it "sets the default action as :add" do
    expect(resource.action).to eql([:add])
  end

  it "builds a default value for chef_binary_path dist values" do
    expect(resource.chef_binary_path).to eql("/opt/chef/bin/chef-client")
  end

  it "log_directory is on macOS" do
    node.automatic_attrs[:platform_family] = "mac_os_x"
    node.automatic_attrs[:platform] = "mac_os_x"
    expect(resource.log_directory).to eql("/Library/Logs/Chef")
  end

  it "log_directory is on non-macOS systems" do
    node.automatic_attrs[:platform_family] = "ubuntu"
    expect(resource.log_directory).to eql("/var/log/chef")
  end

  it "supports :add and :remove actions" do
    expect { resource.action :add }.not_to raise_error
    expect { resource.action :remove }.not_to raise_error
  end

  describe "#splay_sleep_time" do
    it "uses shard_seed attribute if present" do
      node.automatic_attrs[:shard_seed] = "73399073"
      expect(provider.splay_sleep_time(300)).to eql("73399073")
    end

    it "uses a hex conversion of a md5 hash of the splay if present" do
      node.automatic_attrs[:shard_seed] = nil
      allow(node).to receive(:name).and_return("test_node")
      expect(provider.splay_sleep_time(300)).to eql(114)
    end
  end

  describe "#cron_command" do
    before do
      node.automatic_attrs[:shard_seed] = "73399073"
    end

    it "creates a valid command if using all default properties" do
      expect(provider.cron_command).to eql("/bin/sleep 73399073; /opt/chef/bin/chef-client > /var/log/chef/client.log 2>&1")
    end

    it "uses daemon_options if set" do
      resource.daemon_options ["--foo 1", "--bar 2"]
      expect(provider.cron_command).to eql("/bin/sleep 73399073; /opt/chef/bin/chef-client --foo 1 --bar 2 > /var/log/chef/client.log 2>&1")
    end

    it "uses custom log files / paths if set" do
      resource.log_file_name "my-client.log"
      resource.log_directory "/var/log/my-chef/"
      expect(provider.cron_command).to eql("/bin/sleep 73399073; /opt/chef/bin/chef-client > /var/log/my-chef/my-client.log 2>&1")
    end

    it "uses mailto if set" do
      resource.mailto "bob@example.com"
      expect(provider.cron_command).to eql("/bin/sleep 73399073; /opt/chef/bin/chef-client > /var/log/chef/client.log 2>&1 || echo \"Chef Infra Client execution failed\"")
    end

    it "uses custom chef-client binary if set" do
      resource.chef_binary_path "/usr/local/bin/chef-client"
      expect(provider.cron_command).to eql("/bin/sleep 73399073; /usr/local/bin/chef-client > /var/log/chef/client.log 2>&1")
    end

    it "appends to the log file appending if set" do
      resource.append_log_file true
      expect(provider.cron_command).to eql("/bin/sleep 73399073; /opt/chef/bin/chef-client >> /var/log/chef/client.log 2>&1")
    end
  end
end
