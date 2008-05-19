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

require File.expand_path(File.join(File.dirname(__FILE__), "..", "spec_helper"))

class Fakestore
  attr_accessor :name
  
  def to_json(*a)
    { :name => @name }.to_json(*a)
  end
  
  def self.json_create(o)
    new_fakestore = new
    new_fakestore.name = o[:name]
    new_fakestore
  end
end

describe Chef::FileStore do
  before(:each) do
    Chef::Config[:file_store_path] = "/tmp/chef-test"
    @fakestore = Fakestore.new
    @fakestore.name = "Landslide"
    @fakestore_digest = "a56a428bddac69e505731708ba206da0bb75e8de883bb4d5ef6be9b327da556a"
  end
  
  it "should return a path to a file given a type and key" do
    Dir.stub!(:mkdir).and_return(true)
    File.stub!(:directory?).and_return(true)
    path = Chef::FileStore.create_store_path("fakestore", @fakestore.name)
    path.should eql("/tmp/chef-test/fakestore/a/56a/Landslide")
  end
  
  it "should create directories for the path if needed" do
    File.stub!(:directory?).and_return(false)
    Dir.should_receive(:mkdir).exactly(4).times.and_return(true)
    Chef::FileStore.create_store_path("fakestore", @fakestore.name)
  end
 
  it "should store an object with a type and key" do
    Chef::FileStore.should_receive(:create_store_path).with("fakestore", @fakestore.name).and_return("/monkey")
    File.stub!(:directory?).and_return(true)
    ioobj = mock("IO", :null_object => true)
    ioobj.should_receive(:puts).with(@fakestore.to_json)
    ioobj.should_receive(:close).once.and_return(true)
    File.should_receive(:open).with("/monkey", "w").and_return(ioobj)    
    Chef::FileStore.store("fakestore", @fakestore.name, @fakestore)
  end
    
  it "should load an object from the store with type and key" do
    Chef::FileStore.should_receive(:create_store_path).with("fakestore", @fakestore.name).and_return("/monkey")
    File.stub!(:exists?).and_return(true)
    IO.should_receive(:read).once.and_return(true)
    JSON.should_receive(:parse).and_return(true)
    Chef::FileStore.load("fakestore", @fakestore.name)
  end
  
  it "should through an exception if it cannot load a file from the store" do
    Chef::FileStore.should_receive(:create_store_path).and_return("/tmp")
    File.stub!(:exists?).and_return(false)
    lambda { Chef::FileStore.load("fakestore", @fakestore.name) }.should raise_error(RuntimeError)
  end
  
  it "should delete a file from the store if it exists" do
    Chef::FileStore.should_receive(:create_store_path).with("node", "nothing").and_return("/tmp/foolio")
    File.stub!(:exists?).and_return(true)
    File.should_receive(:unlink).with("/tmp/foolio").and_return(1)
    Chef::FileStore.delete("node", "nothing")
  end
  
  it "should list all the keys of a particular type" do
    Dir.should_receive(:[]).with("/tmp/chef-test/node/**/*").and_return(["pool"])
    File.should_receive(:file?).with("pool").and_return(true)
    Chef::FileStore.list("node").should eql(["pool"])
  end

end