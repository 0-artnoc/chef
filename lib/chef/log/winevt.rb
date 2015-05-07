#
# Author:: Jay Mundrawala (<jdm@chef.io>)
#
# Copyright:: 2015, Chef Software, Inc.
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

require 'chef/event_loggers/base'
require 'chef/platform/query_helpers'
require 'chef/mixin/unformatter'

if Chef::Platform::windows? and not Chef::Platform::windows_server_2003?
  if defined? Windows::Constants
    [:INFINITE, :WAIT_FAILED, :FORMAT_MESSAGE_IGNORE_INSERTS, :ERROR_INSUFFICIENT_BUFFER].each do |c|
      # These are redefined in 'win32/eventlog'
      Windows::Constants.send(:remove_const, c) if Windows::Constants.const_defined? c
    end
  end

  require 'win32/eventlog'
end

class Chef
  class Log
    #
    # Chef::Log::WinEvt class.
    # usage in client.rb:
    #  log_location Chef::Log::WinEvt.new
    #
    class WinEvt
      # These must match those that are defined in the manifest file
      INFO_EVENT_ID = 10100
      WARN_EVENT_ID = 10101
      DEBUG_EVENT_ID = 10102
      FATAL_EVENT_ID = 10103

      # Since we must install the event logger, this is not really configurable
      SOURCE = 'Chef'

      include Chef::Mixin::Unformatter

      attr_accessor :sync, :formatter, :level

      def initialize
        @eventlog = ::Win32::EventLog::open('Application')
      end

      def close
      end

      def info(msg)
        @eventlog.report_event(
          :event_type => ::Win32::EventLog::INFO_TYPE,
          :source => SOURCE,
          :event_id => INFO_EVENT_ID,
          :data => [msg]
        )
      end

      def warn(msg)
        @eventlog.report_event(
          :event_type => ::Win32::EventLog::WARN_TYPE,
          :source => SOURCE,
          :event_id => WARN_EVENT_ID,
          :data => [msg]
        )
      end

      def debug(msg)
        @eventlog.report_event(
          :event_type => ::Win32::EventLog::INFO_TYPE,
          :source => SOURCE,
          :event_id => DEBUG_EVENT_ID,
          :data => [msg]
        )
      end

      def fatal(msg)
        @eventlog.report_event(
          :event_type => ::Win32::EventLog::ERROR_TYPE,
          :source => SOURCE,
          :event_id => FATAL_EVENT_ID,
          :data => [msg]
        )
      end

    end
  end
end
