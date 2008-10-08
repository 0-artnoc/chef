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

require 'rubygems'
require 'spec/story'

require File.join(File.dirname(__FILE__), "..", "lib", "chef")
Dir[File.join(File.dirname(__FILE__), 'lib', '**', '*.rb')].sort.each { |lib| require lib }

Chef::Config.log_level(:fatal)
Chef::Config[:couchdb_database] = "chef_test"

def create_couchdb_database
  c = Chef::CouchDB.new
  c.create_db
end

