#
# Author:: AJ Christensen (<aj@chef.io>)
# Author:: Mark Mzyk (mmzyk@chef.io)
# Copyright:: Copyright 2008-2019, Chef Software Inc.
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

require_relative "base"
require_relative "../../chef"
require_relative "client"
require "fileutils" unless defined?(FileUtils)
require "pathname" unless defined?(Pathname)

class Chef::Application::Solo < Chef::Application::Base

  option :config_file,
    short: "-c CONFIG",
    long: "--config CONFIG",
    default: Chef::Config.platform_specific_path("#{Chef::Dist::CONF_DIR}/solo.rb"),
    description: "The configuration file to use."

  unless Chef::Platform.windows?
    option :daemonize,
      short: "-d",
      long: "--daemonize",
      description: "Daemonize the process.",
      proc: lambda { |p| true }
  end

  option :recipe_url,
    short: "-r RECIPE_URL",
    long: "--recipe-url RECIPE_URL",
    description: "Pull down a remote gzipped tarball of recipes and untar it to the cookbook cache."

  option :ez,
    long: "--ez",
    description: "A memorial for Ezra Zygmuntowicz.",
    boolean: true

  option :delete_entire_chef_repo,
    long: "--delete-entire-chef-repo",
    description: "DANGEROUS: does what it says, only useful with --recipe-url.",
    boolean: true

  option :solo_legacy_mode,
    long: "--legacy-mode",
    description: "Run #{Chef::Dist::SOLO} in legacy mode.",
    boolean: true

  # Get this party started
  def run(enforce_license: false)
    setup_signal_handlers
    setup_application
    reconfigure
    check_license_acceptance if enforce_license
    for_ezra if Chef::Config[:ez]
    if !Chef::Config[:solo_legacy_mode]
      Chef::Application::Client.new.run
    else
      run_application
    end
  end

  def reconfigure
    super

    load_dot_d(Chef::Config[:solo_d_dir]) if Chef::Config[:solo_d_dir]

    set_specific_recipes

    Chef::Config[:solo] = true

    if !Chef::Config[:solo_legacy_mode]
      # Because we re-parse ARGV when we move to chef-client, we need to tidy up some options first.
      ARGV.delete("--ez")

      # For back compat reasons, we need to ensure that we try and use the cache_path as a repo first
      Chef::Log.trace "Current chef_repo_path is #{Chef::Config.chef_repo_path}"

      if !Chef::Config.key?(:cookbook_path) && !Chef::Config.key?(:chef_repo_path)
        Chef::Config.chef_repo_path = Chef::Config.find_chef_repo_path(Chef::Config[:cache_path])
      end

      Chef::Config[:local_mode] = true
      Chef::Config[:listen] = false
    else
      configure_legacy_mode!
    end
  end

  def configure_legacy_mode!
    if Chef::Config[:daemonize]
      Chef::Config[:interval] ||= 1800
    end

    # supervisor processes are enabled by default for interval-running processes but not for one-shot runs
    if Chef::Config[:client_fork].nil?
      Chef::Config[:client_fork] = !!Chef::Config[:interval]
    end

    Chef::Application.fatal!(unforked_interval_error_message) if !Chef::Config[:client_fork] && Chef::Config[:interval]

    if Chef::Config[:recipe_url]
      cookbooks_path = Array(Chef::Config[:cookbook_path]).detect { |e| Pathname.new(e).cleanpath.to_s =~ %r{/cookbooks/*$} }
      recipes_path = File.expand_path(File.join(cookbooks_path, ".."))

      if Chef::Config[:delete_entire_chef_repo]
        Chef::Log.trace "Cleanup path #{recipes_path} before extract recipes into it"
        FileUtils.rm_rf(recipes_path, secure: true)
      end
      Chef::Log.trace "Creating path #{recipes_path} to extract recipes into"
      FileUtils.mkdir_p(recipes_path)
      tarball_path = File.join(recipes_path, "recipes.tgz")
      fetch_recipe_tarball(Chef::Config[:recipe_url], tarball_path)
      Mixlib::Archive.new(tarball_path).extract(Chef::Config.chef_repo_path, perms: false, ignore: /^\.$/)
    end

    # json_attribs shuld be fetched after recipe_url tarball is unpacked.
    # Otherwise it may fail if points to local file from tarball.
    if Chef::Config[:json_attribs]
      config_fetcher = Chef::ConfigFetcher.new(Chef::Config[:json_attribs])
      @chef_client_json = config_fetcher.fetch_json
    end
  end

  def run_application
    if !Chef::Config[:client_fork] || Chef::Config[:once]
      begin
        # run immediately without interval sleep, or splay
        run_chef_client(Chef::Config[:specific_recipes])
      rescue SystemExit
        raise
      rescue Exception => e
        Chef::Application.fatal!("#{e.class}: #{e.message}", e)
      end
    else
      interval_run_chef_client
    end
  end

  private

  def for_ezra
    puts <<~EOH
      For Ezra Zygmuntowicz:
        The man who brought you Chef Solo
        Early contributor to Chef
        Kind hearted open source advocate
        Rest in peace, Ezra.
    EOH
  end

  def interval_run_chef_client
    if Chef::Config[:daemonize]
      Chef::Daemon.daemonize("#{Chef::Dist::CLIENT}")
    end

    loop do
      begin

        sleep_sec = 0
        sleep_sec += rand(Chef::Config[:splay]) if Chef::Config[:splay]
        sleep_sec += Chef::Config[:interval] if Chef::Config[:interval]
        if sleep_sec != 0
          Chef::Log.trace("Sleeping for #{sleep_sec} seconds")
          sleep(sleep_sec)
        end

        run_chef_client
        unless Chef::Config[:interval]
          Chef::Application.exit! "Exiting", 0
        end
      rescue SystemExit => e
        raise
      rescue Exception => e
        if Chef::Config[:interval]
          Chef::Log.error("#{e.class}: #{e}")
          Chef::Log.trace("#{e.class}: #{e}\n#{e.backtrace.join("\n")}")
          retry
        else
          Chef::Application.fatal!("#{e.class}: #{e.message}", e)
        end
      end
    end
  end
end
