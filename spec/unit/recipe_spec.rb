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

describe Chef::Recipe do
  before(:each) do
    @recipe = Chef::Recipe.new("hjk", "test", Chef::Node.new)
  end
 
  it "should load a two word (zen_master) resource" do
    lambda do
      @recipe.zen_master "monkey" do
        peace true
      end
    end.should_not raise_error(ArgumentError)
  end
  
  it "should load a one word (cat) resource" do
    lambda do
      @recipe.cat "loulou" do
        pretty_kitty true
      end
    end.should_not raise_error(ArgumentError)
  end
  
  it "should throw an error if you access a resource that we can't find" do
    lambda { @recipe.not_home { || } }.should raise_error(NameError)
  end
  
  it "should allow regular errors (not NameErrors) to pass unchanged" do
    lambda { 
      @recipe.cat { || raise ArgumentError, "You Suck" } 
    }.should raise_error(ArgumentError)
  end
  
  it "should add our zen_master to the collection" do
    @recipe.zen_master "monkey" do
      peace true
    end
    @recipe.collection.lookup("zen_master[monkey]").name.should eql("monkey")
  end
  
  it "should add our zen masters to the collection in the order they appear" do
    %w{monkey dog cat}.each do |name|
      @recipe.zen_master name do
        peace true
      end
    end
    @recipe.collection.each_index do |i|
      case i
      when 0
        @recipe.collection[i].name.should eql("monkey")
      when 1
        @recipe.collection[i].name.should eql("dog")
      when 2
        @recipe.collection[i].name.should eql("cat")
      end
    end
  end
  
  it "should return the new resource after creating it" do
    res = @recipe.zen_master "makoto" do
      peace true
    end
    res.resource_name.should eql(:zen_master)
    res.name.should eql("makoto")
  end
    
  it "should handle an instance_eval properly" do
    code = <<-CODE
zen_master "gnome" do
  peace = true
end
CODE
    lambda { @recipe.instance_eval(code) }.should_not raise_error
    @recipe.resources(:zen_master => "gnome").name.should eql("gnome")
  end
  
  it "should execute defined resources" do
    crow_define = Chef::ResourceDefinition.new
    crow_define.define :crow, :peace => false, :something => true do
      zen_master "lao tzu" do
        peace params[:peace]
        something params[:something]
      end
    end
    @recipe.definitions[:crow] = crow_define
    @recipe.crow "mine" do
      peace true
    end
    @recipe.resources(:zen_master => "lao tzu").name.should eql("lao tzu")
    @recipe.resources(:zen_master => "lao tzu").something.should eql(true)
  end

  it "should load a resource from a ruby file" do
    @recipe.from_file(File.join(File.dirname(__FILE__), "..", "data", "recipes", "test.rb"))
    res = @recipe.resources(:file => "/etc/nsswitch.conf")
    res.name.should eql("/etc/nsswitch.conf")
    res.action.should eql(:create)
    res.owner.should eql("root")
    res.group.should eql("root")
    res.mode.should eql(0644)
  end
  
  it "should raise an exception if the file cannot be found or read" do
    lambda { @recipe.from_file("/tmp/monkeydiving") }.should raise_error(IOError)
  end
  
  it "should evaluate another recipe with recipe_require" do
    Chef::Config.cookbook_path File.join(File.dirname(__FILE__), "..", "data", "cookbooks")
    @recipe.cookbook_loader.load_cookbooks
    @recipe.require_recipe "openldap::gigantor"
    res = @recipe.resources(:cat => "blanket")
    res.name.should eql("blanket")
    res.pretty_kitty.should eql(false)
  end
  
  it "should load the default recipe for a cookbook if require_recipe is called without a ::" do
    Chef::Config.cookbook_path File.join(File.dirname(__FILE__), "..", "data", "cookbooks")
    @recipe.cookbook_loader.load_cookbooks
    @recipe.require_recipe "openldap"
    res = @recipe.resources(:cat => "blanket")
    res.name.should eql("blanket")
    res.pretty_kitty.should eql(true)
  end

end