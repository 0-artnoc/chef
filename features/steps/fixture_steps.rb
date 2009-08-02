
require 'ostruct'

Before do
  @fixtures = {
    'signing_caller' =>{ 
      :user_id=>'bobo', :secret_key => "/tmp/poop.pem"
    },
    'registration' => { 
      'bobo' => Proc.new do

        OpenStruct.new({ :save => true })
     #Chef::CouchDB.new(Chef::Config[:couchdb_url], "chef_integration"))
      end
    },
    'data_bag' => {
      'users' => Proc.new do
        b = Chef::DataBag.new(Chef::CouchDB.new(nil, "chef_integration"))
        b.name "users"
        b
      end,
      'rubies' => Proc.new do
        b = Chef::DataBag.new(Chef::CouchDB.new(nil, "chef_integration"))
        b.name "rubies"
        b
      end
    },
    'data_bag_item' => {
      'francis' => Proc.new do
        i = Chef::DataBagItem.new(Chef::CouchDB.new(nil, "chef_integration"))
        i.data_bag "users"
        i.raw_data = { "id" => "francis" }
        i
      end,
      'francis_extra' => Proc.new do
        i = Chef::DataBagItem.new(Chef::CouchDB.new(nil, "chef_integration"))
        i.data_bag "users"
        i.raw_data = { "id" => "francis", "extra" => "majority" }
        i
      end,
      'axl_rose' => Proc.new do
        i = Chef::DataBagItem.new(Chef::CouchDB.new(nil, "chef_integration"))
        i.data_bag "users"
        i.raw_data = { "id" => "axl_rose" }
        i
      end
    },
    'role' => {
      'webserver' => Proc.new do
        r = Chef::Role.new(Chef::CouchDB.new(nil, "chef_integration"))
        r.name "webserver"
        r.description "monkey"
        r.recipes("role::webserver", "role::base")
        r.default_attributes({ 'a' => 'b' })
        r.override_attributes({ 'c' => 'd' })
        r 
      end,
      'db' => Proc.new do
        r = Chef::Role.new(Chef::CouchDB.new(nil, "chef_integration"))
        r.name "db"
        r.description "monkey"
        r.recipes("role::db", "role::base")
        r.default_attributes({ 'a' => 'bake' })
        r.override_attributes({ 'c' => 'down' })
        r 
      end
    },
    'node' => {
      'webserver' => Proc.new do
        n = Chef::Node.new(Chef::CouchDB.new(nil, "chef_integration"))
        n.name 'webserver'
        n.run_list << "tacos"
        n.snakes "on a plane"
        n.zombie "we're not unreasonable, I mean no-ones gonna eat your eyes"
        n
      end,
      'dbserver' => Proc.new do
        n = Chef::Node.new(Chef::CouchDB.new(nil, "chef_integration"))
        n.name 'dbserver'
        n.run_list << "oracle"
        n.just "kidding - who uses oracle?"
        n
      end,
      'sync' => Proc.new do
        n = Chef::Node.new(Chef::CouchDB.new(nil, "chef_integration"))
        n.name 'sync'
        n.run_list << "node_cookbook_sync"
        n
      end
    }
  }
  @stash = {}
end

def sign_request(http_method, private_key, user_id, body = "")
  timestamp = Time.now.utc.iso8601
  sign_obj = Mixlib::Auth::SignedHeaderAuth.signing_object(
                                                     :http_method=>http_method,
                                                     :body=>body,
                                                     :user_id=>user_id,
                                                     :timestamp=>timestamp)
  signed =  sign_obj.sign(private_key).merge({:host => "localhost"})
  signed.inject({}){|memo, kv| memo["#{kv[0].to_s.upcase}"] = kv[1];memo}
end

def get_fixture(stash_name, stash_key)
  fixy = @fixtures[stash_name][stash_key]
  if fixy.kind_of?(Proc)
    fixy.call
  else
    fixy
  end
end

Given /^an? '(.+)' named '(.+)'$/ do |stash_name, stash_key|
  # BUGBUG: I need to reference fixtures individually, but the fixtures, as written, store under the type, not the fixture's identifier and I don't currently have time to re-write the tests

  key = case stash_name
        when 'file','hash'
          stash_key
        else
          stash_name
        end
  @stash[key] = get_fixture(stash_name, stash_key)
end

Given /^an? '(.+)' named '(.+)' exists$/ do |stash_name, stash_key|  
  @stash[stash_name] = get_fixture(stash_name, stash_key) 
    
  if stash_name == 'registration'
    r = Chef::REST.new(Chef::Config[:registration_url], Chef::Config[:validation_user], Chef::Config[:validation_key])
    r.register("bobo", "#{tmpdir}/bobo.pem")
    @rest = Chef::REST.new(Chef::Config[:registration_url], 'bobo', "#{tmpdir}/bobo.pem")
  else 
    if @stash[stash_name].respond_to?(:save)#stash_name == "registration" 
      @stash[stash_name].save
    else
      request("#{stash_name.pluralize}", { 
        :method => "POST", 
        "HTTP_ACCEPT" => 'application/json',
        "CONTENT_TYPE" => 'application/json',
        :input => @stash[stash_name].to_json 
      }.merge(sign_request("POST", OpenSSL::PKey::RSA.new(IO.read("#{tmpdir}/client.pem")), "bobo")))
    end
  end
end

Given /^sending the method '(.+)' to the '(.+)' with '(.+)'/ do |method, stash_name, update_value|
  update_value = JSON.parse(update_value) if update_value =~ /^\[|\{/
  @stash[stash_name].send(method.to_sym, update_value)
end

Given /^changing the '(.+)' field '(.+)' to '(.+)'$/ do |stash_name, stash_key, stash_value|
  @stash[stash_name].send(stash_key.to_sym, stash_value)
end

Given /^removing the '(.+)' field '(.+)'$/ do |stash_name, key|
  @stash[stash_name].send(key.to_sym, '')
end

Given /^there are no (.+)$/ do |stash_name|
  case stash_name
  when 'roles'
    Chef::Role.list(true).each { |r| r.destroy }
  end
end

Given /^I wait for '(\d+)' seconds$/ do |time|
  sleep time.to_i
end
