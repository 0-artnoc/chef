
Before do
  @fixtures = {
    'registration' => { 
      'bobo' => Proc.new do
        r = Chef::OpenIDRegistration.new
        r.name = "bobo"
        r.set_password('tclown')
        r.validated = true
        r.admin = true
        r
      end
    },
    'role' => {
      'webserver' => Proc.new do
        r = Chef::Role.new
        r.name "webserver"
        r.description "monkey"
        r.recipes("role::webserver", "role::base")
        r.default_attributes({ 'a' => 'b' })
        r.override_attributes({ 'c' => 'd' })
        r 
      end
    }
  }
  @stash = {}
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
  @stash[stash_name] = get_fixture(stash_name, stash_key)
end

Given /^an? '(.+)' named '(.+)' exists$/ do |stash_name, stash_key|
  @stash[stash_name] = get_fixture(stash_name, stash_key) 
  if @stash[stash_name].respond_to?(:save)
    @stash[stash_name].save
  else
    request("/#{stash_name.pluralize}", { 
      :method => "POST", 
      "HTTP_ACCEPT" => 'application/json',
      "CONTENT_TYPE" => 'application/json',
      :input => @stash[stash_name].to_json 
    })
  end
end

Given /^changing the '(.+)' field '(.+)' to '(.+)'$/ do |stash_name, stash_key, stash_value|
  @stash[stash_name][stash_key.to_sym] = stash_value
end

Given /^removing the '(.+)' field '(.+)'$/ do |stash_name, key|
  @stash[stash_name].delete(key.to_sym)
end

Given /^there are no .+$/ do
  # No-Op
end
