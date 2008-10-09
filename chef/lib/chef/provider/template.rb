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

require File.join(File.dirname(__FILE__), "file")
require File.join(File.dirname(__FILE__), "..", "mixin", "template")
require 'uri'
require 'tempfile'

class Chef
  class Provider
    class Template < Chef::Provider::File
      
      include Chef::Mixin::Template
      
      def action_create
        r = Chef::REST.new(Chef::Config[:template_url])

        template_url = generate_url(@new_resource.source, "templates")
        raw_template_file = r.get_rest(template_url, true)
        
        context = @new_resource.variables
        context[:node] = @node
        template_file = render_template(::File.read(raw_template_file.path), context)

        update = false
      
        if ::File.exists?(@new_resource.path)
          @new_resource.checksum(self.checksum(template_file.path))
          if @new_resource.checksum != @current_resource.checksum
            Chef::Log.debug("#{@new_resource} changed from #{@current_resource.checksum} to #{@new_resource.checksum}")
            Chef::Log.info("Updating #{@new_resource} at #{@new_resource.path}")
            update = true
          end
        else
          Chef::Log.info("Creating #{@new_resource} at #{@new_resource.path}")
          update = true
        end
      
        if update
          backup
          FileUtils.cp(template_file.path, @new_resource.path)
          @new_resource.updated = true
        else
          Chef::Log.debug("#{@new_resource} is unchanged")
        end
      
        set_owner if @new_resource.owner != nil
        set_group if @new_resource.group != nil
        set_mode if @new_resource.mode != nil
      end
      
      def action_create_if_missing
        if ::File.exists?(@new_resource.path)
          Chef::Log.debug("File #{@new_resource.path} exists, taking no action.")
        else
          action_create
        end
      end
      
    end
  end
end