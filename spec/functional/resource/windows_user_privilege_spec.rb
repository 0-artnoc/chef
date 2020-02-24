#
# Author:: Vasundhara Jagdale (<vasundhara.jagdale@chef.io>)
# Copyright 2008-2019, Chef Software, Inc.

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#     http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require_relative "../../spec_helper"
require_relative "../../functional/resource/base"

describe Chef::Resource::WindowsUserPrivilege, :windows_only do
  include Chef::Mixin::PowershellOut

  let(:principal) { nil }
  let(:privilege) { nil }
  let(:users) { nil }
  let(:sensitive) { true }

  let(:windows_test_run_context) do
    node = Chef::Node.new
    node.consume_external_attrs(OHAI_SYSTEM.data, {}) # node[:languages][:powershell][:version]
    node.automatic["os"] = "windows"
    node.automatic["platform"] = "windows"
    node.automatic["platform_version"] = "6.1"
    node.automatic["kernel"][:machine] = :x86_64 # Only 64-bit architecture is supported
    empty_events = Chef::EventDispatch::Dispatcher.new
    Chef::RunContext.new(node, {}, empty_events)
  end

  subject do
    new_resource = Chef::Resource::WindowsUserPrivilege.new(principal, windows_test_run_context)
    new_resource.privilege = privilege
    new_resource.principal = principal
    new_resource.users = users
    new_resource
  end

  describe "#add privilege" do
    after { subject.run_action(:remove) }

    let(:principal) { "Administrator" }
    let(:privilege) { "SeCreateSymbolicLinkPrivilege" }

    it "adds user to privilege" do
      subject.run_action(:add)
      expect(subject).to be_updated_by_last_action
    end

    it "is idempotent" do
      subject.run_action(:add)
      subject.run_action(:add)
      expect(subject).not_to be_updated_by_last_action
    end
  end

  describe "#set privilege" do
    before(:all) {
      powershell_out!("Uninstall-Module -Name cSecurityOptions") unless powershell_out!("(Get-Package -Name cSecurityOptions -WarningAction SilentlyContinue).name").stdout.empty?
    }

    let(:principal) { "user_privilege" }
    let(:users) { %w{Administrators Administrator} }
    let(:privilege) { %w{SeCreateSymbolicLinkPrivilege} }

    it "raises error if cSecurityOptions is not installed." do
      subject.action(:set)
      expect { subject.run_action(:set) }.to raise_error(RuntimeError)
    end
  end

  describe "#set privilege" do
    before(:all) {
      powershell_out!("Install-Module -Name cSecurityOptions -Force") if powershell_out!("(Get-Package -Name cSecurityOptions -WarningAction SilentlyContinue).name").stdout.empty?
    }

    after { remove_user_privilege("Administrator", subject.privilege) }

    let(:principal) { "user_privilege" }
    let(:users) { %w{Administrators Administrator} }
    let(:privilege) { %w{SeCreateSymbolicLinkPrivilege} }

    it "sets user to privilege" do
      subject.action(:set)
      subject.run_action(:set)
      expect(subject).to be_updated_by_last_action
    end

    it "is idempotent" do
      subject.action(:set)
      subject.run_action(:set)
      subject.run_action(:set)
      expect(subject).not_to be_updated_by_last_action
    end

    it "raise error if users not provided" do
      subject.users = nil
      subject.action(:set)
      expect { subject.run_action(:set) }.to raise_error(Chef::Exceptions::ValidationFailed)
    end
  end

  describe "#remove privilege" do
    let(:principal) { "Administrator" }
    let(:privilege) { "SeCreateSymbolicLinkPrivilege" }

    it "remove user from privilege" do
      subject.run_action(:add)
      subject.run_action(:remove)
      expect(subject).to be_updated_by_last_action
    end
  end

  def remove_user_privilege(user, privilege)
    subject.action(:remove)
    subject.principal = user
    subject.privilege = privilege
    subject.run_action(:remove)
  end
end
