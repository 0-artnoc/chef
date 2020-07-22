#
# Author:: Snehal Dwivedi (<sdwivedi@msystechnologies.com>)
# Copyright:: Copyright (c) Chef Software Inc.
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
require "chef/org"

describe Chef::Knife::OpcUserPassword do

  before :each do
    @knife = Chef::Knife::OpcUserPassword.new
    @user_name = "foobar"
    @password = "abc123"
    @user = double("Chef::User")
    allow(Chef::User).to receive(:new).and_return(@user)
    @key = "You don't come into cooking to get rich - Ramsay"
  end

  let(:rest) do
    Chef::Config[:chef_server_root] = "http://www.example.com"
    root_rest = double("rest")
    allow(Chef::ServerAPI).to receive(:new).and_return(root_rest)
  end

  describe "should change user's password" do
    before :each do
      @knife.name_args << @user_name << @password
    end

    it "with username and password" do
      result = { "password" => [], "recovery_authentication_enabled" => true }

      allow(@knife).to receive(:root_rest).and_return(rest)
      allow(@user).to receive(:[]).with("organization")

      expect(rest).to receive(:get).with("users/#{@user_name}").and_return(result)
      expect(rest).to receive(:put).with("users/#{@user_name}", result)
      expect(@knife.ui).to receive(:msg).with("Authentication info updated for #{@user_name}.")

      @knife.run
    end
  end

  describe "should not change user's password" do

    it "ails with an informative message" do
      expect(@knife).to receive(:show_usage)
      expect(@knife.ui).to receive(:fatal).with("You must pass two arguments")
      expect(@knife.ui).to receive(:fatal).with("Note that --enable-external-auth cannot be passed with a password")
      expect { @knife.run }.to raise_error(SystemExit)
    end
  end
end
