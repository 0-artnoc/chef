#
# Author:: Adam Jacob (<adam@hjksolutions.com>)
# Copyright:: Copyright (c) 2008 HJK Solutions, LLC
# License:: GNU General Public License version 2 or later
# 
# This program and entire repository is free software; you can
# redistribute it and/or modify it under the terms of the GNU 
# General Public License as published by the Free Software 
# Foundation; either version 2 of the License, or any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#

require 'ostruct'

require File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "spec_helper"))

describe Chef::Provider::Directory do
  before(:each) do
    @new_resource = mock("New Resource", :null_object => true)
    @new_resource.stub!(:name).and_return("directory")
    @new_resource.stub!(:path).and_return("/tmp")
    @new_resource.stub!(:owner).and_return(500)
    @new_resource.stub!(:group).and_return(500)
    @new_resource.stub!(:mode).and_return(0644)    
    @new_resource.stub!(:updated).and_return(false)
    @node = Chef::Node.new
    @node.name "latte"
    @directory = Chef::Provider::Directory.new(@node, @new_resource)
  end
  
  it "should load the current resource based on the new resource" do
    File.should_receive(:exist?).once.and_return(true)
    File.should_receive(:directory?).once.and_return(true)
    cstats = mock("stats", :null_object => true)
    cstats.stub!(:uid).and_return(500)
    cstats.stub!(:gid).and_return(500)
    cstats.stub!(:mode).and_return(0755)
    File.should_receive(:stat).once.and_return(cstats)
    @directory.load_current_resource
    @directory.current_resource.path.should eql(@new_resource.path)
    @directory.current_resource.owner.should eql(500)
    @directory.current_resource.group.should eql(500)
    @directory.current_resource.mode.should eql("755")
  end
  
  it "should create a new directory on create, setting updated to true" do
    load_mock_provider
    File.should_receive(:exists?).once.and_return(false)
    Dir.should_receive(:mkdir).with(@new_resource.path).once.and_return(true)
    @directory.new_resource.should_receive(:updated=).with(true)
    @directory.should_receive(:set_owner).once.and_return(true)
    @directory.should_receive(:set_group).once.and_return(true)
    @directory.should_receive(:set_mode).once.and_return(true)
    @directory.action_create
  end
  
  it "should not create the directory if it already exists" do
    load_mock_provider
    File.should_receive(:exists?).once.and_return(true)
    Dir.should_not_receive(:mkdir).with(@new_resource.path)
    @directory.stub!(:set_owner).and_return(true)
    @directory.stub!(:set_group).and_return(true)
    @directory.stub!(:set_mode).and_return(true)
    @directory.action_create  
  end
  
  it "should delete the directory if it exists, and is writable with action_delete" do
    load_mock_provider
    File.should_receive(:exists?).once.and_return(true)
    File.should_receive(:writable?).once.and_return(true)
    Dir.should_receive(:delete).with(@new_resource.path).once.and_return(true)
    @directory.action_delete
  end
  
  it "should raise an exception if it cannot delete the file due to bad permissions" do
    load_mock_provider
    File.stub!(:exists?).and_return(true)
    File.stub!(:writable?).and_return(false)
    lambda { @directory.action_delete }.should raise_error(RuntimeError)
  end
  
  def load_mock_provider
    File.stub!(:exist?).and_return(true)
    File.stub!(:directory?).and_return(true)
    cstats = mock("stats", :null_object => true)
    cstats.stub!(:uid).and_return(500)
    cstats.stub!(:gid).and_return(500)
    cstats.stub!(:mode).and_return(0755)
    File.stub!(:stat).once.and_return(cstats)
    @directory.load_current_resource
  end
end