#
# Author:: Chirag Jog (<chirag@clogeny.com>)
# Author:: Siddheshwar More (<siddheshwar.more@clogeny.com>)
# Copyright:: Copyright (c) 2013 Opscode, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'spec_helper'
require 'functional/resource/base'

describe Chef::Resource::Group, :requires_root_or_running_windows do
  def group_should_exist(group)
    case ohai[:platform_family]
    when "debian", "fedora", "rhel", "suse", "gentoo", "slackware", "arch"
      expect { Etc::getgrnam(group) }.to_not raise_error(ArgumentError, "can't find group for #{group}")
      expect(group).to eq(Etc::getgrnam(group).name)
    when "windows"
      expect { Chef::Util::Windows::NetGroup.new(group).local_get_members }.to_not raise_error(ArgumentError, "The group name could not be found.")
    end
  end

  def user_exist_in_group?(user)
    case ohai[:platform_family]
    when "windows"
      Chef::Util::Windows::NetGroup.new(group_name).local_get_members.include?(user)
    else
      Etc::getgrnam(group_name).mem.include?(user)
    end
  end

  def group_should_not_exist(group)
    case ohai[:platform_family]
    when "debian", "fedora", "rhel", "suse", "gentoo", "slackware", "arch"
      expect { Etc::getgrnam(group) }.to raise_error(ArgumentError, "can't find group for #{group}")
    when "windows"
      expect { Chef::Util::Windows::NetGroup.new(group).local_get_members }.to raise_error(ArgumentError, "The group name could not be found.")
    end
  end

  def compare_gid(resource, gid)
    return resource.gid == Etc::getgrnam(resource.name).gid if unix?
  end

  def user(username)
    usr = Chef::Resource::User.new("#{username}", run_context)
    usr
  end

  def create_user(username)
    user(username).run_action(:create)
    # TODO: User shouldn't exist
  end

  def remove_user(username)
    user(username).run_action(:remove)
    # TODO: User shouldn't exist
  end

  shared_examples_for "correct group management" do
    def add_members_to_group(members)
      temp_resource = group_resource.dup
      temp_resource.members(members)
      temp_resource.excluded_members([ ])
      temp_resource.append(true)
      temp_resource.run_action(:modify)
      members.each do |member|
        user_exist_in_group?(member).should == true
      end
    end

    def create_group
      temp_resource = group_resource.dup
      temp_resource.members([ ])
      temp_resource.excluded_members([ ])
      temp_resource.run_action(:create)
      group_should_exist(group_name)
      included_members.each do |member|
        user_exist_in_group?(member).should == false
      end
    end

    before(:each) do
      create_group
    end

    after(:each) do
      group_resource.run_action(:remove)
      group_should_not_exist(group_name)
    end

    describe "when append is not set" do
      let(:included_members) { ["group-spec-Eric"] }

      before do
        create_user("group-spec-Eric")
        create_user("group-spec-Gordon")
        add_members_to_group(["group-spec-Gordon"])
      end

      after do
        remove_user("group-spec-Eric")
        remove_user("group-spec-Gordon")
      end

      it "should remove the existing users and add the new users to the group" do
        group_resource.run_action(tested_action)

        user_exist_in_group?("group-spec-Eric").should == true
        user_exist_in_group?("group-spec-Gordon").should == false
      end
    end

    describe "when append is set" do
      before(:each) do
        group_resource.append(true)
      end

      describe "when the users exist" do
        before do
          (included_members + excluded_members).each do |member|
            create_user(member)
          end
        end

        after do
          (included_members + excluded_members).each do |member|
            remove_user(member)
          end
        end

        it "should add included members to the group" do
          group_resource.run_action(tested_action)

          included_members.each do |member|
            user_exist_in_group?(member).should == true
          end
          excluded_members.each do |member|
            user_exist_in_group?(member).should == false
          end
        end

        describe "when group contains some users" do
          before(:each) do
            add_members_to_group([ "group-spec-Gordon", "group-spec-Anthony" ])
          end

          it "should add the included users and remove excluded users" do
            group_resource.run_action(tested_action)

            included_members.each do |member|
              user_exist_in_group?(member).should == true
            end
            excluded_members.each do |member|
              user_exist_in_group?(member).should == false
            end
          end
        end
      end

      describe "when the users doesn't exist" do
        describe "when append is not set" do
          it "should raise an error" do
            lambda { @grp_resource.run_action(tested_action) }.should raise_error
          end
        end

        describe "when append is set" do
          it "should raise an error" do
            lambda { @grp_resource.run_action(tested_action) }.should raise_error
          end
        end
      end
    end
  end

  let(:group_name) { "test-group-#{SecureRandom.random_number(9999)}" }
  let(:included_members) { nil }
  let(:excluded_members) { nil }
  let(:group_resource) {
    group = Chef::Resource::Group.new(group_name, run_context)
    group.members(included_members)
    group.excluded_members(excluded_members)
    group
  }

  it "append should be false by default" do
    group_resource.append.should == false
  end

  describe "group create action" do
    after(:each) do
      group_resource.run_action(:remove)
      group_should_not_exist(group_name)
    end

    it "should create a group" do
      group_resource.run_action(:create)
      group_should_exist(group_name)
    end

    describe "when group name is length 256", :windows_only do
      before(:each) do
        let!(:group_name) { "theoldmanwalkingdownthestreetalwayshadagood\
smileonhisfacetheoldmanwalkingdownthestreetalwayshadagoodsmileonhisface\
theoldmanwalkingdownthestreetalwayshadagoodsmileonhisfacetheoldmanwalking\
downthestreetalwayshadagoodsmileonhisfacetheoldmanwalkingdownthestree" }
      end

      it "should create a group" do
        group_resource.run_action(:create)
        group_should_exist(group_name)
      end
    end

    describe "when group name length is more than 256", :windows_only do
      before(:each) do
        let!(:group_name) { "theoldmanwalkingdownthestreetalwayshadagood\
smileonhisfacetheoldmanwalkingdownthestreetalwayshadagoodsmileonhisface\
theoldmanwalkingdownthestreetalwayshadagoodsmileonhisfacetheoldmanwalking\
downthestreetalwayshadagoodsmileonhisfacetheoldmanwalkingdownthestreeQQQQQQ" }
      end

      it "should not create a group" do
        lambda { group_resource.run_action(:create) }.should raise_error
        group_should_not_exist(group_name)
      end
    end

    describe "should raise an error when same member is included in the members and excluded_members" do
      it "should raise an error" do
        invalid_resource = group_resource.dup
        invalid_resource.members(["Jack"])
        invalid_resource.excluded_members(["Jack"])
        lambda { invalid_resource.run_action(:create)}.should raise_error(Chef::Exceptions::ConflictingMembersInGroup)
      end
    end
  end

  describe "group remove action" do
    describe "when there is a group" do
      before do
        group_resource.run_action(:create)
        group_should_exist(group_name)
      end

      it "should remove a group" do
        group_resource.run_action(:remove)
        group_should_not_exist(group_name)
      end
    end

    describe "when there is no group" do
      it "should be no-op" do
        group_resource.run_action(:remove)
        group_should_not_exist(group_name)
      end
    end
  end

  describe "group modify action" do
    let(:included_members) { ["group-spec-Gordon", "group-spec-Eric"] }
    let(:excluded_members) { ["group-spec-Anthony"] }
    let(:tested_action) { :modify }

    describe "when there is no group" do
      it "should raise an error" do
        lambda { group_resource.run_action(:modify) }.should raise_error
      end
    end

    describe "when there is a group" do
      it_behaves_like "correct group management"
    end
  end

  describe "group manage action" do
    let(:included_members) { ["group-spec-Gordon", "group-spec-Eric"] }
    let(:excluded_members) { ["group-spec-Anthony"] }
    let(:tested_action) { :manage }

    describe "when there is no group" do
      it "should raise an error" do
        lambda { group_resource.run_action(:manage) }.should_not raise_error
        group_should_not_exist(group_name)
      end
    end

    describe "when there is a group" do
      it_behaves_like "correct group management"
    end
  end
end

