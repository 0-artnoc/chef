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

describe Chef::Provider do
  before(:each) do
    @resource = Chef::Resource.new("funk")
    @node = Chef::Node.new
    @node.name "latte"
    @provider = Chef::Provider.new(@node, @resource)
  end
  
  it "should return a Chef::Provider" do
    @provider.should be_a_kind_of(Chef::Provider)
  end
  
  it "should store the resource passed to new as new_resource" do
    @provider.new_resource.should eql(@resource)
  end
  
  it "should store the node passed to new as node" do
    @provider.node.should eql(@node)
  end
  
  it "should have nil for current_resource by default" do
    @provider.current_resource.should eql(nil)
  end    
  
  it "should return true for action_nothing" do
    @provider.action_nothing.should eql(true)
  end
end