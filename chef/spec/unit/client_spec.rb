#
# Author:: Adam Jacob (<adam@hjksolutions.com>)
# Copyright:: Copyright (c) 2008 HJK Solutions, LLC
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

require File.expand_path(File.join(File.dirname(__FILE__), "..", "spec_helper"))

describe Chef::Client, "initialize" do
  it "should create a new Chef::Client object" do
    Chef::Client.new.should be_kind_of(Chef::Client)
  end
end

describe Chef::Client, "build_node" do
  before(:each) do
    @mock_facter_fqdn = mock("Facter FQDN")
    @mock_facter_fqdn.stub!(:value).and_return("foo.bar.com")
    @mock_facter_hostname = mock("Facter Hostname")
    @mock_facter_hostname.stub!(:value).and_return("foo")
    Facter.stub!(:[]).with("fqdn").and_return(@mock_facter_fqdn)
    Facter.stub!(:[]).with("hostname").and_return(@mock_facter_hostname)
    Facter.stub!(:each).and_return(true)
    @client = Chef::Client.new
  end
  
  it "should set the name equal to the FQDN" do
    @client.build_node
    @client.node.name.should eql("foo.bar.com")
  end
  
  it "should set the name equal to the hostname if FQDN is not available" do
    @mock_facter_fqdn.stub!(:value).and_return(nil)
    @client.build_node
    @client.node.name.should eql("foo")
  end
end

describe Chef::Client, "register" do
  before(:each) do
    @client = Chef::Client.new
  end
  
  it "should check to see if it's already registered"
  
  it "should create a new passphrase if not registered"
  
  it "should create a new registration if it has not registered"
end