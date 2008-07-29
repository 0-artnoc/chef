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

require File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "spec_helper"))

describe Chef::Resource::Template do

  before(:each) do
    @resource = Chef::Resource::Template.new("fakey_fakerton")
  end  

  it "should create a new Chef::Resource::Template" do
    @resource.should be_a_kind_of(Chef::Resource)
    @resource.should be_a_kind_of(Chef::Resource::File)
    @resource.should be_a_kind_of(Chef::Resource::Template)
  end

  it "should accept a string for the template name" do
    @resource.template "something"
    @resource.template.should eql("something")
  end
  
  it "should accept a hash for the variable list" do
    @resource.variables({ :reluctance => :awkward })
    @resource.variables.should == { :reluctance => :awkward }
  end
  
end