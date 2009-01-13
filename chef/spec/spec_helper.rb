# Author:: Adam Jacob (<adam@opscode.com>)
# Copyright:: Copyright (c) 2008 Opscode, Inc.
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

$:.unshift(File.join(File.dirname(__FILE__), "..", "lib"))

require 'chef'

chef_lib_path = File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib'))
Dir[
  File.expand_path(
    File.join(
      chef_lib_path, 'chef', '**', '*.rb'
    )
  )
].sort.each do |lib|
  lib_short_path = lib.match("^#{chef_lib_path}#{File::SEPARATOR}(.+)$")[1]
  require lib_short_path
end
Dir[File.join(File.dirname(__FILE__), 'lib', '**', '*.rb')].sort.each { |lib| require lib }

Chef::Config.log_level(:fatal)
