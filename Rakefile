# -*- ruby -*-
require 'rubygems'
require 'rake/gempackagetask'
require './lib/chef.rb'
require './tasks/rspec.rb'

GEM = "chef"
VERSION = "0.0.1"
AUTHOR = "Adam Jacob"
EMAIL = "adam@hjksolutions.com"
HOMEPAGE = "http://hjksolutions.com"
SUMMARY = "A configuration management system."

spec = Gem::Specification.new do |s|
  s.name = GEM
  s.version = VERSION
  s.platform = Gem::Platform::RUBY
  s.has_rdoc = true
  s.extra_rdoc_files = ["README.txt", "LICENSE", 'NOTICE']
  s.summary = SUMMARY
  s.description = s.summary
  s.author = AUTHOR
  s.email = EMAIL
  s.homepage = HOMEPAGE
  
  # Uncomment this to add a dependency
  s.add_dependency "stomp"
  s.add_dependency "stompserver"
  s.add_dependency "ferret"
  s.add_dependency "facter"
  s.add_dependency "merb-core"
  s.add_dependency "haml"
  s.add_dependency "ruby-openid"
  s.add_dependency "json"
  
  s.bindir       = "bin"
  s.executables  = %w( chef-client chef-indexer chef-server chef-solo )
  
  s.require_path = 'lib'
  s.files = %w(LICENSE README.txt Rakefile) + Dir.glob("{lib,specs}/**/*")
end

Rake::GemPackageTask.new(spec) do |pkg|
  pkg.gem_spec = spec
end

task :install => [:package] do
  sh %{sudo gem install pkg/#{GEM}-#{VERSION}}
end

# vim: syntax=Ruby
