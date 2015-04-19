#
# Author:: Ranjib Dey (<ranjib@linux.com>)
# Copyright:: Copyright (c) 2015 Ranjib Dey
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
require 'chef/event_dispatch/base'
require 'chef/exceptions'
require 'chef/config'

class Chef
  module EventDispatch
    class DSL
      # Adds a new event handler derived from base handler
      # with user defined block against a chef event
      #
      # @return [Chef::EventDispatch::Base] a base handler object
      def on(event_type, &block)
        validate!(event_type)
        handler = Chef::EventDispatch::Base.new
        handler.define_singleton_method(event_type) do |*args|
          block.call(args)
        end
        Chef::Config[:event_handlers] << handler
        handler
      end

      private
      def validate!(event_type)
        all_event_types = (Chef::EventDispatch::Base.instance_methods - Object.instance_methods)
        raise Chef::Exceptions::UnknownEventType unless all_event_types.include?(event_type)
      end
    end
  end
end
