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

require 'digest/md5'
require 'etc'

class Chef
  class Provider
    class File < Chef::Provider
      def load_current_resource
        @current_resource = Chef::Resource::File.new(@new_resource.name)
        @current_resource.path(@new_resource.path)
        if ::File.exist?(@current_resource.path) && ::File.readable?(@current_resource.path)
          cstats = ::File.stat(@current_resource.path)
          @current_resource.owner(cstats.uid)
          @current_resource.group(cstats.gid)
          @current_resource.mode("%o" % (cstats.mode & 007777))
        end
        @current_resource
      end
      
      def checksum
        digest = Digest::MD5.new
        IO.foreach(@current_resource.path) do |line|
          digest << line
        end
        @current_resource.checksum(digest.hexdigest)
      end
      
      # Compare the ownership of a file.  Returns true if they are the same, false if they are not.
      def compare_owner
        case @new_resource.owner
        when /^\d+$/, Integer
          @set_user_id = @new_resource.owner.to_i
          @set_user_id == @current_resource.owner
        else
          # This raises an ArugmentError if you can't find the user         
          user_info = Etc.getpwnam(@new_resource.owner)
          @set_user_id = user_info.uid
          @set_user_id == @current_resource.owner
        end
      end
      
      # Set the ownership on the file, assuming it is not set correctly already.
      def set_owner
        unless compare_owner
          ::File.chown(@set_user_id, nil, @new_resource.path)
        end
      end
      
      # Compares the group of a file.  Returns true if they are the same, false if they are not.
      def compare_group
        case @new_resource.group
        when /^\d+$/, Integer
          @set_group_id = @new_resource.group.to_i
          @set_group_id == @current_resource.group
        else
          group_info = Etc.getpwnam(@new_resource.group)
          @set_group_id = group_info.gid
          @set_group_id == @current_resource.group
        end
      end
      
      def set_group
        unless compare_group
          ::File.chown(nil, @set_group_id, @new_resource.path)
        end
      end
      
      def action_create
        unless ::File.exists?(@new_resource.path)
          ::File.open(@new_resource.path, "w+") { |f| }
        end
        set_owner
        set_group
      end
      
      def action_delete
        if ::File.exists?(@new_resource.path) && ::File.writable?(@new_resource.path)
          ::File.delete(@new_resource.path)
        end
      end
      
    end
  end
end