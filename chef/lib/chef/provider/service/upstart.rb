#
# Author:: Bryan McLellan <btm@loftninjas.org>
# Copyright:: Copyright (c) 2010 Bryan McLellan
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

require 'chef/provider/service'
require 'chef/provider/service/simple'
require 'chef/mixin/command'

class Chef
  class Provider
    class Service
      class Upstart < Chef::Provider::Service::Simple
       
        # Upstart does more than start or stop a service, creating multiple 'states' [1] that a service can be in.
        # In chef, when we ask a service to start, we expect it to have started before performing the next step
        # since we have top down dependencies. Which is to say we may follow witha resource next that requires
        # that service to be running. According to [2] we can trust that sending a 'goal' such as start will not
        # return until that 'goal' is reached, or some error has occured.
        #
        # [1] http://upstart.ubuntu.com/wiki/JobStates
        # [2] http://www.netsplit.com/2008/04/27/upstart-05-events/

        def initialize(node, new_resource, collection=nil, definitions=nil, cookbook_loader=nil)
          super(node, new_resource, collection, definitions, cookbook_loader)
        end

        def load_current_resource
          @current_resource = Chef::Resource::Service.new(@new_resource.name)
          @current_resource.service_name(@new_resource.service_name)

          # We do not support searching for a service via ps when using upstart since status is a native
          # upstart function. We will however support status_command in case someone wants to do something special.

          if @new_resource.status_command
            Chef::Log.debug("#{@new_resource} you have specified a status command, running..")

            begin
              if run_command(:command => @new_resource.status_command) == 0
                @current_resource.running true
              end
            rescue Chef::Exceptions::Exec
              @current_resource.running false
              nil
            end
          else
            begin
              if run_command(:command => "/sbin/status #{@current_resource.service_name}") == 0
                @current_resource.running true
              end
            rescue Chef::Exceptions::Exec
              @current_resource.running false
              nil
            end
          end
        end

        def start_service
          # Calling start on a service that is already started will return 1
          # Our 'goal' when we call start is to ensure the service is started
          if @current_resource.running
            Chef::Log.debug("#{@new_resource}: Already running, not starting")
          else
            if @new_resource.start_command
              super
            else
              run_command(:command => "/sbin/start #{@new_resource.service_name}")
            end
          end
        end

        def stop_service
          # Calling stop on a service that is already stopped will return 1
          # Our 'goal' when we call stop is to ensure the service is stopped
          unless @current_resource.running
            Chef::Log.debug("#{@new_resource}: Not running, not stopping")
          else
            if @new_resource.stop_command
              super
            else
              run_command(:command => "/sbin/stop #{@new_resource.service_name}")
            end
          end
        end

        def restart_service
          if @new_resource.restart_command
            super
          else
            run_command(:command => "/sbin/restart #{@new_resource.service_name}")
          end
        end

        def reload_service
          if @new_resource.reload_command
            super
          else
            # upstart >= 0.6.3-4 supports reload (HUP)
            run_command(:command => "/sbin/reload #{@new_resource.service_name}")
          end
        end
      end
    end
  end
end
