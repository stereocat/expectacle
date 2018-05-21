# frozen_string_literal: true

require 'pty'
require 'expect'
require 'yaml'
require 'erb'
require 'logger'
require 'syslog/logger'

module Expectacle
  # Basic state setup/management
  class ThrowerBase
    # @return [Logger] Logger instance.
    attr_accessor :logger
    # @return [String] Base directory path to find params/hosts/commands file.
    attr_reader :base_dir

    # Constructor
    # @param timeout [Integer] Seconds to timeout. (default: 60sec)
    # @param verbose [Boolean] Flag to enable verbose output.
    #   (default: `true`)
    # @param base_dir [String] Base directory to find files.
    #   (default: `Dir.pwd`)
    # @param logger [IO,String,Symbol] IO Object (default `$stdout`),
    #   File name, or :syslog to logging.
    # @return [Expectacle::ThrowerBase]
    def initialize(timeout: 60, verbose: true,
                   base_dir: Dir.pwd, logger: $stdout)
      # default
      @host_param = {}
      # remote connection timeout (sec)
      @timeout = timeout
      # cli mode flag
      @enable_mode = false
      # debug (use debug print to stdout)
      $expect_verbose = verbose
      # base dir
      @base_dir = File.expand_path(base_dir)
      # logger
      setup_default_logger(logger)
    end

    # Path to prompt file directory.
    # @return [String]
    def prompts_dir
      File.join @base_dir, 'prompts'
    end

    # Path to host list file directory.
    # @return [String]
    def hosts_dir
      File.join @base_dir, 'hosts'
    end

    # Path to command list file directory.
    # @return [String]
    def commands_dir
      File.join @base_dir, 'commands'
    end

    # Path to span command options file directory.
    # @return [String]
    def opts_dir
      File.join @base_dir, 'opts'
    end

    private

    def default_io_logger(logger_io, progname)
      logger = Logger.new(logger_io)
      logger.progname = progname
      logger.datetime_format = '%Y-%m-%d %H:%M:%D %Z'
      logger
    end

    def setup_default_logger(logger)
      progname = 'Expectacle'
      @logger = if logger == :syslog
                  Syslog::Logger.new(progname)
                else
                  default_io_logger(logger, progname)
                end
      @logger.level = Logger::INFO
      @logger.formatter = proc do |severity, datetime, pname, msg|
        "#{datetime} #{pname} [#{severity}] #{msg}\n"
      end
    end

    def ready_to_open_host_session
      @local_serial = false # default for host
      load_prompt_file # prompt regexp of device
      spawn_cmd = make_spawn_command
      if @prompt && spawn_cmd
        yield spawn_cmd
      else
        @logger.error 'Invalid parameter in param file(S)'
      end
    end

    def do_on_interactive_process
      until @reader.closed? || @reader.eof?
        @reader.expect(expect_regexp, @timeout) do |match|
          yield match
        end
      end
    rescue Errno::EIO => error
      # on linux, PTY raises Errno::EIO when spawned process closed.
      @logger.debug "PTY raises Errno::EIO, #{error.message}"
    end

    def open_interactive_process(spawn_cmd)
      @logger.info "Begin spawn: #{spawn_cmd}"
      PTY.spawn(spawn_cmd) do |reader, writer, _pid|
        @enable_mode = false
        @reader = reader
        @writer = writer
        @writer.sync = true
        yield
      end
    end

    def ssh_command
      opts = load_spawn_command_opts_file
      ['ssh', opts, "-l #{embed_user_name}", embed_ipaddr].join(' ')
    end

    def cu_command
      @local_serial = true
      # @serial_exit = '~.'
      opts = load_spawn_command_opts_file
      ['cu', @host_param[:cu_opts], opts].join(' ')
    end

    def make_spawn_command
      case @host_param[:protocol]
      when /^telnet$/i
        ['telnet', embed_ipaddr].join(' ')
      when /^ssh$/i
        ssh_command
      when /^cu$/i
        cu_command
      else
        @logger.error "Unknown protocol #{@host_param[:protocol]}"
        nil
      end
    end

    def load_yaml_file(file_type, file_name)
      YAML.load_file file_name
    rescue StandardError => error
      @logger.error "Cannot load #{file_type}: #{file_name}"
      raise error
    end

    def load_prompt_file
      prompt_file = "#{prompts_dir}/#{@host_param[:type]}_prompt.yml"
      @prompt = load_yaml_file('prompt file', prompt_file)
    end

    def load_spawn_command_opts_file
      opts_file = "#{opts_dir}/#{@host_param[:protocol]}_opts.yml"
      if File.exist?(opts_file)
        load_yaml_file("#{@host_param[:protocol]} opts file", opts_file)
      else
        @logger.warn "Opts file #{opts_file} not found."
        []
      end
    end

    def expect_regexp
      /
        ( #{@prompt[:password]} | #{@prompt[:enable_password]}
        | #{@prompt[:username]}
        | #{@prompt[:command1]} | #{@prompt[:command2]}
        | #{@prompt[:sub1]} | #{@prompt[:sub2]}
        | #{@prompt[:yn]}
        )\s*$
      /x
    end

    def write_and_logging(message, command, secret = false)
      logging_message = secret ? message : message + command
      @logger.info logging_message
      @writer.puts command
    end

    def check_embed_envvar(command)
      return unless command =~ /<%=\s*ENV\[[\'\"]?(.+)[\'\"]\]?\s*%>/
      envvar_name = Regexp.last_match(1)
      if !ENV.key?(envvar_name)
        @logger.error "Variable name: #{envvar_name} is not found in ENV"
      elsif ENV[envvar_name] =~ /^\s*$/
        @logger.warn "Env var: #{envvar_name} exists, but null string"
      end
    end

    def embed_password
      @host_param[:enable] = '_NOT_DEFINED_' unless @host_param.key?(:enable)
      base_str = @enable_mode ? @host_param[:enable] : @host_param[:password]
      check_embed_envvar(base_str)
      passwd_erb = ERB.new(base_str)
      passwd_erb.result(binding)
    end

    def embed_command(command)
      command_erb = ERB.new(command)
      command_erb.result(binding)
    end

    def embed_user_name
      check_embed_envvar(@host_param[:username])
      uname_erb = ERB.new(@host_param[:username])
      uname_erb.result(binding)
    end

    def embed_ipaddr
      check_embed_envvar(@host_param[:ipaddr])
      ipaddr_erb = ERB.new(@host_param[:ipaddr])
      ipaddr_erb.result(binding)
    end
  end
end
