#!/usr/bin/env ruby

## release.rb #################################################################
#------------------------------------------------------------------------------
# This script runs from the root of a jenkins workspace where artifacts from
# the omnibus build matrix are collected.
#
# # Primary command line options:
# * `--project PROJECT`: Project to be released. This also controls where the
#   script looks for config JSON.
# * `--bucket S3_BUCKET`: Name of the S3 bucket where artifacts are released
#   to.
#
# Other options are available, run `release.rb --help`.
#
# # Config
# release.rb looks in the same directory where it's located for files named
# "$project.json" and "$project-platform-names.json".
#
# ## $project.json
# The project.json file controls the mapping of build platforms to release
# platforms so that a single build artifact can be reused on compatible
# platforms. See chef.json for an example.
#
# ## $project-platform-names.json
# The project-platform-names.json file maps short platform names to long ones.
# see chef-platform-names.json for an example.
#
# # Tests
# This file contains the script's tests. Tests are written in rspec. To run the
# tests, run rspec with this file as the argument, e.g.,
# `rspec -cfs release.rb`.

require 'rubygems'
require 'json'
require 'optparse'
require 'mixlib/shellout'

# Represnts the collection of artifacts on disk that we plan to upload. Handles
# finding the artifacts and dealing with the mapping between build platform and
# install platforms.
class ArtifactCollection

  class MissingArtifact < RuntimeError
  end

  attr_reader :project
  attr_reader :config

  def initialize(project, config)
    @project = project
    @config = config
  end

  def platform_map_json
    IO.read(File.expand_path("../#{project}.json", __FILE__))
  end

  def platform_map
    JSON.parse(platform_map_json)
  end

  def platform_name_map_json
    IO.read(File.expand_path("../#{project}-platform-names.json", __FILE__))
  end

  def platform_name_map
    JSON.parse(platform_name_map_json)
  end

  def package_paths
    @package_paths ||= Dir['**/pkg/*'].reject {|path| path.include?("BUILD_VERSION") }
  end

  def artifacts
    artifacts = []
    missing_packages = []
    platform_map.each do |build_platform_spec, supported_platforms|
      if path = package_paths.find { |p| p.include?(build_platform_spec) }
        artifacts << Artifact.new(path, supported_platforms, config)
      else
        missing_packages << build_platform_spec
      end
    end
    error_on_missing_pkgs!(missing_packages)
    artifacts
  end

  def error_on_missing_pkgs!(missing_packages)
    unless missing_packages.empty?
      if config[:ignore_missing_packages]
        missing_packages.each do |pkg_config|
          # TODO: this should go to $stderr
          puts "WARN: Missing package for config: #{pkg_config}"
        end
      else
        raise MissingArtifact, "Missing packages for config(s): '#{missing_packages.join("' '")}'"
      end
    end
  end
end

# Represents an individual package which has one or more supported platforms.
class Artifact

  attr_reader :path
  attr_reader :platforms
  attr_reader :config

  def initialize(path, platforms, config)
    @path = path
    @platforms = platforms
    @config = config
  end

  def add_to_release_manifest!(release_manifest)
    platforms.each do |distro, version, arch|
      release_manifest[distro] ||= {}
      release_manifest[distro][version] ||= {}
      release_manifest[distro][version][arch] = { build_version => relpath }
    end
    release_manifest
  end

  def build_platform
    platforms.first
  end

  def build_version
    config[:version]
  end

  def relpath
    # upload build to build platform directory
    "/#{build_platform.join('/')}/#{path.split('/').last}"
  end

  def md5
    digest(Digest::MD5)
  end

  def sha256_file
    digest(Digest::SHA256)
  end

  private

  def digest(digest_class)
    File.open(path) do |io|
      digest = digest_class.new
      while chunk = io.read(1024 * 8)
        digest.update(chunk)
      end
      digest.hexdigest
    end
  end
end

if $0.include?("rspec")
  describe ArtifactCollection do

    # project_json is the thing that maps a build to. It is stored in the same
    # directory with basename determined by project, e.g., "chef.json" for
    # chef-client, "chef-server.json" for chef-server. By convention, the first
    # entry is the platform that we actually do the build on.
    let(:platform_map_json) do
      <<-E
{
    "build_os=centos-5,machine_architecture=x64,role=oss-builder": [
        [
            "el",
            "5",
            "x86_64"
        ],
        [
            "sles",
            "11.2",
            "x86_64"
        ]
    ],
    "build_os=centos-5,machine_architecture=x86,role=oss-builder": [
        [
            "el",
            "5",
            "i686"
        ],
        [
            "sles",
            "11.2",
            "i686"
        ]
    ]
}
E
    end

    let(:platform_map) do
      JSON.parse(platform_map_json)
    end

    # mapping of short platform names to longer ones.
    # This file lives in this script's directory under $project-platform-names.json
    let(:platform_name_map_json) do
      <<-E
{
    "el" : "Enterprise Linux",
    "debian" : "Debian",
    "mac_os_x" : "OS X",
    "ubuntu" : "Ubuntu", 
    "solaris2" : "Solaris",
    "sles" : "SUSE Enterprise",
    "suse" : "openSUSE",
    "windows" : "Windows"
}
E
    end

    let(:platform_name_map) do
      JSON.parse(platform_name_map_json)
    end

    let(:directory_contents) do
      %w[
        build_os=centos-5,machine_architecture=x64,role=oss-builder/pkg/demoproject-10.22.0-1.el5.x86_64.rpm
        build_os=centos-5,machine_architecture=x64,role=oss-builder/pkg/BUILD_VERSION
        build_os=centos-5,machine_architecture=x86,role=oss-builder/pkg/demoproject-10.22.0-1.el5.i686.rpm
        build_os=centos-5,machine_architecture=x86,role=oss-builder/pkg/BUILD_VERSION
      ]
    end

    let(:artifact_collection) do
      ArtifactCollection.new("demoproject", {})
    end

    it "has a project name" do
      artifact_collection.project.should == "demoproject"
    end

    it "has config" do
      artifact_collection.config.should == {}
    end

    it "loads the mapping of build platforms to install platforms from the local copy" do
      expected_path = File.expand_path("../demoproject.json", __FILE__)
      IO.should_receive(:read).with(expected_path).and_return(platform_map_json)
      artifact_collection.platform_map_json.should == platform_map_json
    end

    it "loads the mapping of platform short names to long names from the local copy" do
      expected_path = File.expand_path("../demoproject-platform-names.json", __FILE__)
      IO.should_receive(:read).with(expected_path).and_return(platform_name_map_json)
      artifact_collection.platform_name_map_json.should == platform_name_map_json
    end

    it "finds the package files among the artifacts" do
      Dir.should_receive(:[]).with("**/pkg/*").and_return(directory_contents)
      expected = %w[
        build_os=centos-5,machine_architecture=x64,role=oss-builder/pkg/demoproject-10.22.0-1.el5.x86_64.rpm
        build_os=centos-5,machine_architecture=x86,role=oss-builder/pkg/demoproject-10.22.0-1.el5.i686.rpm
      ]
      artifact_collection.package_paths.should == expected
    end

    context "after loading the build and platform mappings" do

      before do
        artifact_collection.should respond_to(:platform_map_json)
        artifact_collection.stub!(:platform_map_json).and_return(platform_map_json)
        artifact_collection.should respond_to(:platform_name_map_json)
        artifact_collection.stub!(:platform_name_map_json).and_return(platform_name_map_json)
      end

      it "parses the build platform mapping" do
        artifact_collection.platform_map.should == platform_map
      end

      it "parses the platform short name => long name mapping" do
        artifact_collection.platform_name_map.should == platform_name_map
      end

      it "returns a list of artifacts for each package" do
        Dir.should_receive(:[]).with("**/pkg/*").and_return(directory_contents)

        artifact_collection.should have(2).artifacts
        centos5_64bit_artifact = artifact_collection.artifacts.first

        path = "build_os=centos-5,machine_architecture=x64,role=oss-builder/pkg/demoproject-10.22.0-1.el5.x86_64.rpm"
        centos5_64bit_artifact.path.should == path

        platforms = [ [ "el", "5", "x86_64" ], [ "sles","11.2","x86_64" ] ]
        centos5_64bit_artifact.platforms.should == platforms
      end

      context "and some expected packages are missing" do
        let(:directory_contents) do
          %w[
            build_os=centos-5,machine_architecture=x86,role=oss-builder/pkg/demoproject-10.22.0-1.el5.i686.rpm
            build_os=centos-5,machine_architecture=x86,role=oss-builder/pkg/BUILD_VERSION
          ]
        end

        before do
          Dir.should_receive(:[]).with("**/pkg/*").and_return(directory_contents)
        end

        it "errors out verifying all packages are available" do
          err_msg = "Missing packages for config(s): 'build_os=centos-5,machine_architecture=x64,role=oss-builder'"
          lambda {artifact_collection.artifacts}.should raise_error(ArtifactCollection::MissingArtifact, err_msg)
        end

      end
    end

  end # describe ArtifactCollection

  describe Artifact do

    let(:path) { "build_os=centos-5,machine_architecture=x86,role=oss-builder/pkg/demoproject-11.4.0-1.el5.x86_64.rpm" }

    let(:platforms) { [ [ "el", "5", "x86_64" ], [ "sles","11.2","x86_64" ] ] }

    let(:artifact) { Artifact.new(path, platforms, { :version => "11.4.0-1" }) }

    it "has the path to the package" do
      artifact.path.should == path
    end

    it "has a list of platforms the package supports" do
      artifact.platforms.should == platforms
    end

    it "adds the package to a release manifest" do
      expected = {
        "el" => {
          "5" => { "x86_64" => { "11.4.0-1" => "/el/5/x86_64/demoproject-11.4.0-1.el5.x86_64.rpm" } }
        },
        "sles" => {
          "11.2" => { "x86_64" => { "11.4.0-1" => "/el/5/x86_64/demoproject-11.4.0-1.el5.x86_64.rpm" } }
        }
      }

      manifest = artifact.add_to_release_manifest!({})
      manifest.should == expected
    end

  end
end



__END__

# OLD MONOLITHIC SCRIPT:

STDOUT.sync = true
# bump mixlib-shellout's default timeout to 20 minutes
# and stream output from forked process
shellout_opts = {:timeout => 1200, :live_stream => STDOUT}

#
# Usage: release.sh --project PROJECT --version VERSION --bucket BUCKET
#

options = {}
optparse = OptionParser.new do |opts|
  opts.banner = "Usage: #{$0} [options]"

  opts.on("-p", "--project PROJECT", "the project to release") do |project|
    options[:project] = project
  end

  opts.on("-v", "--version VERSION", "the version of the installer to release") do |version|
    options[:version] = version
  end

  opts.on("-b", "--bucket S3_BUCKET_NAME", "the name of the s3 bucket to release to") do |bucket|
    options[:bucket] = bucket
  end

  opts.on("--ignore-missing-packages",
          "indicates the release should continue if any build packages are missing") do |missing|
    options[:ignore_missing_packages] = missing
  end
end

# check for an optional BUILD_VERSION file which is generated by the build script
if options[:version].nil?
  # this file should be the same across all platforms so grab the first one
  build_version_file = Dir['**/pkg/BUILD_VERSION'].first
  options[:version] = IO.read(build_version_file).chomp if build_version_file
end

begin
  optparse.parse!
  required = [:project, :version, :bucket]
  missing = required.select {|param| options[param].nil?}
  if !missing.empty?
    puts "Missing required options: #{missing.join(', ')}"
    puts optparse
    exit 1
  end
rescue OptionParser::InvalidOption, OptionParser::MissingArgument
  puts $!.to_s
  puts optparse
  exit 1
end

#
# == Jenkins Build Support Matrix
#
# :key:   - the jenkins build name
# :value: - an Array of Arrays indicating the builds supported by the
#           build. by convention, the first element in the array
#           references the build itself.
#

build_support_file = File.join(File.dirname(__FILE__), "#{options[:project]}.json")

if File.exists?(build_support_file)
  jenkins_build_support = JSON.load(IO.read(build_support_file))
else
  error_msg = "Could not locate build support file for %s at %s."
  raise error_msg % [options[:project], File.expand_path(build_support_file)]
end

platform_names_file = File.join(File.dirname(__FILE__), "#{options[:project]}-platform-names.json")

if not File.exists?(platform_names_file)
  error_msg = "Could not locate platform names file for %s at %s."
  raise error_msg % [options[:project], File.expand_path(platform_names_file)]
end
# fetch the list of local packages
local_packages = Dir['**/pkg/*']

# generate json
build_support_json = {}
jenkins_build_support.each do |(build, supported_platforms)|
  build_platform = supported_platforms.first

  # find the build in the local packages
  build_package = local_packages.find do |b|
    # ensure we ignore the BUILD_VERSION file
    b.include?(build) && !b.include?("BUILD_VERSION")
  end

  unless build_package
    error_msg = "Could not locate build package for [#{build_platform.join("-")}]."
    if options[:ignore_missing_packages]
      puts "WARN: #{error_msg}"
      next
    else
      raise error_msg
    end
  end

  # upload build to build platform directory
  build_location = "/#{build_platform.join('/')}/#{build_package.split('/').last}"
  puts "UPLOAD: #{build_package} -> #{build_location}"

  s3_cmd = ["s3cmd",
            "put",
            "--progress",
            "--acl-public",
            build_package,
            "s3://#{options[:bucket]}#{build_location}"].join(" ")
  shell = Mixlib::ShellOut.new(s3_cmd, shellout_opts)
  shell.run_command
  shell.error!

  ### update json with build information
  ## OLD Build Info w/o Checksums

  supported_platforms.each do |(platform, platform_version, machine_architecture)|
    build_support_json[platform] ||= {}
    build_support_json[platform][platform_version] ||= {}
    build_support_json[platform][platform_version][machine_architecture] = {}
    build_support_json[platform][platform_version][machine_architecture][options[:version]] = build_location
  end

  ## NEW build info w/ checksums

  supported_platforms.each do |(platform, platform_version, machine_architecture)|
    build_support_json[platform] ||= {}
    build_support_json[platform][platform_version] ||= {}
    build_support_json[platform][platform_version][machine_architecture] = {}
    build_support_json[platform][platform_version][machine_architecture][options[:version]] = {}
    build_support_json[platform][platform_version][machine_architecture][options[:version]]["relpath"] = build_location
  end
end

File.open("platform-support.json", "w") {|f| f.puts JSON.pretty_generate(build_support_json)}

s3_location = "s3://#{options[:bucket]}/#{options[:project]}-platform-support/#{options[:version]}.json"
puts "UPLOAD: platform-support.json -> #{s3_location}"
s3_cmd = ["s3cmd",
          "put",
          "platform-support.json",
          s3_location].join(" ")
shell = Mixlib::ShellOut.new(s3_cmd, shellout_opts)
shell.run_command
shell.error!

s3_location = "s3://#{options[:bucket]}/#{options[:project]}-platform-support/#{options[:project]}-platform-names.json"
puts "UPLOAD: #{options[:project]}-platform-names.json -> #{s3_location}"
s3_cmd = ["s3cmd",
          "put",
          platform_names_file,
          s3_location].join(" ")
shell = Mixlib::ShellOut.new(s3_cmd, shellout_opts)
shell.run_command
shell.error!


###############################################################################
# BACKWARD COMPAT HACK
#
# TODO: DELETE EVERYTHING BELOW THIS COMMENT WHEN UPDATED OMNITRUCK IS LIVE
#
# See https://github.com/opscode/omnibus-chef/pull/12#issuecomment-8572411
# for more info.
###############################################################################
if options[:project] == 'chef'
  s3_location = "s3://#{options[:bucket]}/platform-support/#{options[:version]}.json"
  puts "UPLOAD: platform-support.json -> #{s3_location}"
  s3_cmd = ["s3cmd",
            "put",
            "platform-support.json",
            s3_location].join(" ")
  shell = Mixlib::ShellOut.new(s3_cmd, shellout_opts)
  shell.run_command
  shell.error!
end
