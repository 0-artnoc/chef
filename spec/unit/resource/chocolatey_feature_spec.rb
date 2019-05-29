#
# Copyright:: Copyright 2019-2019, Chef Software Inc.
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

describe Chef::Resource::ChocolateyFeature do

  let(:node) { Chef::Node.new }
  let(:events) { Chef::EventDispatch::Dispatcher.new }
  let(:run_context) { Chef::RunContext.new(node, {}, events) }
  let(:resource) { Chef::Resource::ChocolateyFeature.new("fakey_fakerton", run_context) }
  let(:provider) { resource.provider_for_action(:set) }
  let(:current_resource) { Chef::Resource::ChocolateyFeature.new("fakey_fakerton") }

  let(:config) do
    <<-CONFIG
  <?xml version="1.0" encoding="utf-8"?>
  <chocolatey xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
    <config>
      <add key="containsLegacyPackageInstalls" value="true" description="Install has packages installed prior to 0.9.9 series." />
    </config>
    <sources>
      <source id="chocolatey" value="https://chocolatey.org/api/v2/" disabled="false" bypassProxy="false" selfService="false" adminOnly="false" priority="0" />
    </sources>
    <features>
      <feature name="checksumFiles" enabled="true" setExplicitly="false" description="Checksum files when pulled in from internet (based on package)." />
    </features>
    <apiKeys />
  </chocolatey>
    CONFIG
  end

  # we save off the ENV and set ALLUSERSPROFILE so these specs will work on *nix and non-C drive Windows installs
  before(:each) do
    provider # vivify before mocking
    allow(resource).to receive(:provider_for_action).and_return(provider)
    allow(resource).to receive(:dup).and_return(current_resource)
    @original_env = ENV.to_hash
    ENV["ALLUSERSPROFILE"] = 'C:\ProgramData'
  end

  after(:each) do
    ENV.clear
    ENV.update(@original_env)
  end

  it "has a resource name of :chocolatey_feature" do
    expect(resource.resource_name).to eql(:chocolatey_feature)
  end

  it "has a name property of feature_name" do
    expect(resource.feature_name).to eql("fakey_fakerton")
  end

  it "sets the default action as :set" do
    expect(resource.action).to eql([:set])
  end

  it "supports :set action" do
    expect { resource.action :set }.not_to raise_error
  end

  describe "#fetch_feature_element" do
    it "raises and error if the config file cannot be found" do
      allow(::File).to receive(:exist?).with('C:\ProgramData\chocolatey\config\chocolatey.config').and_return(false)
      expect { resource.fetch_feature_element("foo") }.to raise_error(RuntimeError)
    end

    it "returns the value if present in the config file" do
      allow(::File).to receive(:exist?).with('C:\ProgramData\chocolatey\config\chocolatey.config').and_return(true)
      allow(::File).to receive(:read).with('C:\ProgramData\chocolatey\config\chocolatey.config').and_return(config)
      expect(resource.fetch_feature_element("checksumFiles")).to eq("true")
      expect { resource.fetch_feature_element("foo") }.not_to raise_error
    end

    it "returns nil if the element is not present in the config file" do
      allow(::File).to receive(:exist?).with('C:\ProgramData\chocolatey\config\chocolatey.config').and_return(true)
      allow(::File).to receive(:read).with('C:\ProgramData\chocolatey\config\chocolatey.config').and_return(config)
      expect(resource.fetch_feature_element("foo")).to be_nil
      expect { resource.fetch_feature_element("foo") }.not_to raise_error
    end
  end

  describe "#load_current_resource" do
    it "sets the state to :enabled when the XML enabled property is true" do
      allow(current_resource).to receive(:fetch_feature_element).with("fakey_fakerton").and_return("true")
      provider.load_current_resource
      expect(current_resource.state).to be :enabled
    end

    it "sets the state to :disabled when the XML enabled property is false" do
      allow(current_resource).to receive(:fetch_feature_element).with("fakey_fakerton").and_return("false")
      provider.load_current_resource
      expect(current_resource.state).to be :disabled
    end

    it "sets the current_resource to nil when the property is not present" do
      allow(current_resource).to receive(:fetch_feature_element).with("fakey_fakerton").and_return(nil)
      provider.load_current_resource
      expect(provider.current_resource).to be nil
    end
  end

  describe "run_action(:set)" do
    it "when it is disabled, it enables it correctly" do
      resource.state :enabled
      allow(current_resource).to receive(:fetch_feature_element).with("fakey_fakerton").and_return("false")
      expect(provider).to receive(:shell_out!).with("C:\\ProgramData\\chocolatey\\bin\\choco feature enable --name fakey_fakerton")
      resource.run_action(:set)
      expect(resource.updated_by_last_action?).to be true
    end

    it "when it is enabled, it is idempotent when trying to enable" do
      resource.state :enabled
      allow(current_resource).to receive(:fetch_feature_element).with("fakey_fakerton").and_return("true")
      expect(provider).not_to receive(:shell_out!)
      resource.run_action(:set)
      expect(resource.updated_by_last_action?).to be false
    end

    it "when it is disabled, it is idempotent when trying to disable" do
      resource.state :disabled
      allow(current_resource).to receive(:fetch_feature_element).with("fakey_fakerton").and_return("false")
      expect(provider).not_to receive(:shell_out!)
      resource.run_action(:set)
      expect(resource.updated_by_last_action?).to be false
    end

    it "when it is enabled, it is idempotent when trying to enable" do
      resource.state :disabled
      allow(current_resource).to receive(:fetch_feature_element).with("fakey_fakerton").and_return("true")
      expect(provider).to receive(:shell_out!).with("C:\\ProgramData\\chocolatey\\bin\\choco feature disable --name fakey_fakerton")
      resource.run_action(:set)
      expect(resource.updated_by_last_action?).to be true
    end
  end
end
