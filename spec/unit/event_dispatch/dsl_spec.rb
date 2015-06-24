#
# Author:: Ranjib Dey (<ranjib@linux.com>)
#
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
require 'spec_helper'
require 'chef/event_dispatch/dsl'

describe Chef::EventDispatch::DSL do
  subject{ described_class.new('test') }

  it 'raise error when invalid event type is supplied' do
    expect do
      subject.on(:foo_bar) {}
    end.to raise_error(Chef::Exceptions::InvalidEventType)
  end

  it 'register user hooks against valid event type' do
    subject.on(:run_failed) {'testhook'}
    expect(Chef::Config[:event_handlers].first.run_failed).to eq('testhook')
  end

  it 'preserve state across event hooks' do
    Chef::Config.reset!
    node = Chef::Node.new
    calls = []
    Chef.event_handler do
      on :resource_updated do
        calls << :updated
      end
      on :resource_action_start do
        calls << :started
      end
    end
    events = Chef::EventDispatch::Dispatcher.new(*Chef::Config[:event_handlers])
    rc = Chef::RunContext.new(node, nil, events)
    resource = Chef::Resource::RubyBlock.new('foo', rc)
    resource.block { }
    resource.run_action(:run)
    expect(calls).to eq([:started, :updated])
  end

  it 'preserve instance variables across handler callbacks' do
    Chef::Config.reset!
    node = Chef::Node.new
    Chef.event_handler do
      on :resource_action_start do
        @ivar = [1]
      end
      on :resource_updated do
        @ivar << 2
      end
    end
    events = Chef::EventDispatch::Dispatcher.new(*Chef::Config[:event_handlers])
    rc = Chef::RunContext.new(node, nil, events)
    resource = Chef::Resource::RubyBlock.new('foo', rc)
    resource.block { }
    resource.run_action(:run)
    expect(Chef::Config[:event_handlers].first.instance_variable_get(:@ivar)).to eq([1, 2])
  end
end
