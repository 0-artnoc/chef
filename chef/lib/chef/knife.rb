#
# Author:: Adam Jacob (<adam@opscode.com>)
# Author:: Christopher Brown (<cb@opscode.com>)
# Copyright:: Copyright (c) 2009 Opscode, Inc.
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

require 'forwardable'
require 'chef/version'
require 'mixlib/cli'
require 'chef/mixin/convert_to_class_name'
require 'chef/knife/subcommand_loader'
require 'chef/knife/ui'

require 'pp'

class Chef
  class Knife
    include Mixlib::CLI
    extend Chef::Mixin::ConvertToClassName
    extend Forwardable

    # Backwards Compat:
    # Ideally, we should not vomit all of these methods into this base class;
    # instead, they should be accessed by hitting the ui object directly.
    def_delegator :@ui, :stdout
    def_delegator :@ui, :stderr
    def_delegator :@ui, :stdin
    def_delegator :@ui, :msg
    def_delegator :@ui, :ask_question
    def_delegator :@ui, :pretty_print
    def_delegator :@ui, :output
    def_delegator :@ui, :format_list_for_display
    def_delegator :@ui, :format_for_display
    def_delegator :@ui, :format_cookbook_list_for_display
    def_delegator :@ui, :edit_data
    def_delegator :@ui, :edit_object
    def_delegator :@ui, :confirm

    attr_accessor :name_args
    attr_reader :ui

    def self.ui
      @ui ||= Chef::Knife::UI.new(STDOUT, STDERR, STDIN, {})
    end

    def self.msg(msg="")
      ui.msg(msg)
    end

    def self.reset_subcommands!
      @@subcommands = {}
      @subcommands_by_category = nil
    end

    def self.inherited(subclass)
      unless subclass.unnamed?
        subcommands[subclass.snake_case_name] = subclass
      end
    end

    # Explicitly set the category for the current command to +new_category+
    # The category is normally determined from the first word of the command
    # name, but some commands make more sense using two or more words
    # ===Arguments
    # new_category::: A String to set the category to (see examples)
    # ===Examples:
    # Data bag commands would be in the 'data' category by default. To put them
    # in the 'data bag' category:
    #   category('data bag')
    def self.category(new_category)
      @category = new_category
    end

    def self.subcommand_category
      @category || snake_case_name.split('_').first unless unnamed?
    end

    def self.snake_case_name
      convert_to_snake_case(name.split('::').last) unless unnamed?
    end

    # Does this class have a name? (Classes created via Class.new don't)
    def self.unnamed?
      name.nil? || name.empty?
    end

    def self.subcommand_loader
      @subcommand_loader ||= Knife::SubcommandLoader.new(chef_config_dir)
    end

    def self.load_commands
      subcommand_loader.load_commands
    end

    def self.subcommands
      @@subcommands ||= {}
    end

    def self.subcommands_by_category
      unless @subcommands_by_category
        @subcommands_by_category = Hash.new { |hash, key| hash[key] = [] }
        subcommands.each do |snake_cased, klass|
          @subcommands_by_category[klass.subcommand_category] << snake_cased
        end
      end
      @subcommands_by_category
    end

    # Print the list of subcommands knife knows about. If +preferred_category+
    # is given, only subcommands in that category are shown
    def self.list_commands(preferred_category=nil)
      load_commands
      category_desc = preferred_category ? preferred_category + " " : ''
      msg "Available #{category_desc}subcommands: (for details, knife SUB-COMMAND --help)\n\n"

      if preferred_category && subcommands_by_category.key?(preferred_category)
        commands_to_show = {preferred_category => subcommands_by_category[preferred_category]}
      else
        commands_to_show = subcommands_by_category
      end

      commands_to_show.sort.each do |category, commands|
        msg "** #{category.upcase} COMMANDS **"
        commands.each do |command|
          msg subcommands[command].banner if subcommands[command]
        end
        msg
      end
    end

    # Run knife for the given +args+ (ARGV), adding +options+ to the list of
    # CLI options that the subcommand knows how to handle.
    # ===Arguments
    # args::: usually ARGV
    # options::: A Mixlib::CLI option parser hash. These +options+ are how
    # subcommands know about global knife CLI options
    def self.run(args, options={})
      load_commands
      subcommand_class = subcommand_class_from(args)
      subcommand_class.options = options.merge!(subcommand_class.options)
      instance = subcommand_class.new(args)
      instance.configure_chef
      instance.run
    end

    def self.guess_category(args)
      category_words = args.select {|arg| arg =~ /^([[:alnum:]]|_)+$/ }
      matching_category = nil
      while (!matching_category) && (!category_words.empty?)
        candidate_category = category_words.join(' ')
        matching_category = candidate_category if subcommands_by_category.key?(candidate_category)
        matching_category || category_words.pop
      end
      matching_category
    end

    def self.subcommand_class_from(args)
      command_words = args.select {|arg| arg =~ /^([[:alnum:]]|_)+$/ }
      subcommand_class = nil

      while ( !subcommand_class ) && ( !command_words.empty? )
        snake_case_class_name = command_words.join("_")
        unless subcommand_class = subcommands[snake_case_class_name]
          command_words.pop
        end
      end
      subcommand_class || subcommand_not_found!(args)
    end

    protected

    def load_late_dependency(dep, gem_name = nil)
      begin
        require dep
      rescue LoadError
        gem_name ||= dep.gsub('/', '-')
        ui.fatal "#{gem_name} is not installed. run \"gem install #{gem_name}\" to install it."
        exit 1
      end
    end

    private

    # :nodoc:
    # Error out and print usage. probably becuase the arguments given by the
    # user could not be resolved to a subcommand.
    def self.subcommand_not_found!(args)
      unless want_help?(args)
        ui.fatal("Cannot find sub command for: '#{args.join(' ')}'")
      end
      list_commands(guess_category(args))
      exit 10
    end

    # :nodoc:
    # TODO: duplicated with chef/application/knife
    # all logic should be removed from that and Chef::Knife should own it.
    def self.want_help?(args)
      (args.any? { |arg| arg =~ /^(:?(:?\-\-)?help|\-h)$/})
    end

    @@chef_config_dir = nil

    # search upward from current_dir until .chef directory is found
    def self.chef_config_dir
      if @@chef_config_dir.nil? # share this with subclasses
        @@chef_config_dir = false
        full_path = Dir.pwd.split(File::SEPARATOR)
        (full_path.length - 1).downto(0) do |i|
          canidate_directory = File.join(full_path[0..i] + [".chef" ])
          if File.exist?(canidate_directory) && File.directory?(canidate_directory)
            @@chef_config_dir = canidate_directory
            break
          end
        end
      end
      @@chef_config_dir
    end


    public

    # Create a new instance of the current class configured for the given
    # arguments and options
    def initialize(argv=[])
      super() # having to call super in initialize is the most annoying anti-pattern :(
      @ui = Chef::Knife::UI.new(STDOUT, STDERR, STDIN, config)

      command_name_words = self.class.snake_case_name.split('_')

      # Mixlib::CLI ignores the embedded name_args
      @name_args = parse_options(argv)
      @name_args.reject! { |name_arg| command_name_words.delete(name_arg) }

      # knife node run_list add requires that we have extra logic to handle
      # the case that command name words could be joined by an underscore :/
      command_name_words = command_name_words.join('_')
      @name_args.reject! { |name_arg| command_name_words == name_arg }

      if config[:help]
        msg opt_parser
        exit 1
      end
    end

    def parse_options(args)
      super
    rescue OptionParser::InvalidOption => e
      puts "Error: " + e.to_s
      show_usage
      exit(1)
    end

    def configure_chef
      unless config[:config_file]
        if self.class.chef_config_dir
          candidate_config = File.expand_path('knife.rb',self.class.chef_config_dir)
          config[:config_file] = candidate_config if File.exist?(candidate_config)
        end
        # If we haven't set a config yet and $HOME is set, and the home
        # knife.rb exists, use it:
        if (!config[:config_file]) && ENV['HOME'] && File.exist?(File.join(ENV['HOME'], '.chef', 'knife.rb'))
          config[:config_file] = File.join(ENV['HOME'], '.chef', 'knife.rb')
        end
      end

      # Don't try to load a knife.rb if it doesn't exist.
      if config[:config_file]
        Chef::Config.from_file(config[:config_file])
      else
        # ...but do log a message if no config was found.
        self.msg("No knife configuration file found")
      end

      Chef::Config[:log_level]         = config[:log_level]       if config[:log_level]
      Chef::Config[:log_location]      = config[:log_location]    if config[:log_location]
      Chef::Config[:node_name]         = config[:node_name]       if config[:node_name]
      Chef::Config[:client_key]        = config[:client_key]      if config[:client_key]
      Chef::Config[:chef_server_url]   = config[:chef_server_url] if config[:chef_server_url]
      Chef::Config[:environment]       = config[:environment]     if config[:environment]

      # Expand a relative path from the config directory. Config from command
      # line should already be expanded, and absolute paths will be unchanged.
      if Chef::Config[:client_key] && config[:config_file]
        Chef::Config[:client_key] = File.expand_path(Chef::Config[:client_key], File.dirname(config[:config_file]))
      end

      Mixlib::Log::Formatter.show_time = false
      Chef::Log.init(Chef::Config[:log_location])
      Chef::Log.level(Chef::Config[:log_level] || :error)

      Chef::Log.debug("Using configuration from #{config[:config_file]}")

      if Chef::Config[:node_name].nil?
        raise ArgumentError, "No user specified, pass via -u or specifiy 'node_name' in #{config[:config_file] ? config[:config_file] : "~/.chef/knife.rb"}"
      end
    end


    def show_usage
      stdout.puts("USAGE: " + self.opt_parser.to_s)
    end

    def load_from_file(klass, from_file, bag=nil)
      relative_path = ""
      if klass == Chef::Role
        relative_path = "roles"
      elsif klass == Chef::Node
        relative_path = "nodes"
      elsif klass == Chef::DataBagItem
        relative_path = "data_bags/#{bag}"
      elsif klass == Chef::Environment
        relative_path = "environments"
      end

      relative_file = File.expand_path(File.join(Dir.pwd, relative_path, from_file))
      filename = nil

      if file_exists_and_is_readable?(from_file)
        filename = from_file
      elsif file_exists_and_is_readable?(relative_file)
        filename = relative_file
      else
        ui.fatal("Cannot find file #{from_file}")
        exit 30
      end

      case from_file
      when /\.(js|json)$/
        Chef::JSONCompat.from_json(IO.read(filename))
      when /\.rb$/
        r = klass.new
        r.from_file(filename)
        r
      else
        ui.fatal("File must end in .js, .json, or .rb")
        exit 30
      end
    end

    def file_exists_and_is_readable?(file)
      File.exists?(file) && File.readable?(file)
    end

    def create_object(object, pretty_name=nil, &block)
      output = edit_data(object)

      if Kernel.block_given?
        output = block.call(output)
      else
        output.save
      end

      pretty_name ||= output

      self.msg("Created (or updated) #{pretty_name}")

      output(output) if config[:print_after]
    end

    def delete_object(klass, name, delete_name=nil, &block)
      confirm("Do you really want to delete #{name}")

      if Kernel.block_given?
        object = block.call
      else
        object = klass.load(name)
        object.destroy
      end

      output(format_for_display(object)) if config[:print_after]

      obj_name = delete_name ? "#{delete_name}[#{name}]" : object
      self.msg("Deleted #{obj_name}!")
    end

    def bulk_delete(klass, fancy_name, delete_name=nil, list=nil, regex=nil, &block)
      object_list = list ? list : klass.list(true)

      if regex
        to_delete = Hash.new
        object_list.each_key do |object|
          next if regex && object !~ /#{regex}/
          to_delete[object] = object_list[object]
        end
      else
        to_delete = object_list
      end

      output(format_list_for_display(to_delete))

      confirm("Do you really want to delete the above items")

      to_delete.each do |name, object|
        if Kernel.block_given?
          block.call(name, object)
        else
          object.destroy
        end
        output(format_for_display(object)) if config[:print_after]
        self.msg("Deleted #{fancy_name} #{name}")
      end
    end

    def rest
      @rest ||= Chef::REST.new(Chef::Config[:chef_server_url])
    end

  end
end

