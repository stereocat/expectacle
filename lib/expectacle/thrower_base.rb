# frozen_string_literal: true

require 'pty'
require 'expect'
require 'yaml'
require 'erb'
require 'logger'

module Expectacle
  # Basic state setup/management
  class ThrowerBase
    attr_accessor :logger

    def initialize(timeout: 60, verbose: true,
                   base_dir: Dir.pwd, logger: $stdout)
      # remote connection timeout (sec)
      @timeout = timeout
      # cli mode flag
      @enable_mode = false
      # debug (use debug print to stdout)
      $expect_verbose = verbose
      # base dir
      @base_dir = base_dir
      # logger
      setup_default_logger(logger)
    end

    def prompts_dir
      File.expand_path(@base_dir + '/prompts')
    end

    def hosts_dir
      File.expand_path(@base_dir + '/hosts')
    end

    def commands_dir
      File.expand_path(@base_dir + '/commands')
    end

    private

    def do_for_all_hosts(host_list_file)
      # host list to send commands
      @host_list = YAML.load_file("#{hosts_dir}/#{host_list_file}")
      @host_list.each do |host_param|
        @host_param = host_param
        yield
      end
    end

    def ready_to_open_host_session
      # prompt regexp of device
      @prompt = load_prompt_regexp
      spawn_cmd = make_spawn_command
      if @prompt && spawn_cmd
        yield spawn_cmd
      else
        @logger.error 'Invalid parameter in param file(S)'
      end
    end

    def do_on_interactive_process
      until @reader.eof?
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
      @logger.info "End spawn: #{@host_param[:hostname]}"
    end

    def ssh_command
      ['ssh',
       '-o StrictHostKeyChecking=no',
       # for old cisco device
       '-o KexAlgorithms=+diffie-hellman-group1-sha1',
       '-l', embed_user_name(binding),
       @host_param[:ipaddr]].join(' ')
    end

    def make_spawn_command
      case @host_param[:protocol]
      when /^telnet$/i
        ['telnet', @host_param[:ipaddr]].join(' ')
      when /^ssh$/i
        ssh_command
      else
        @logger.error "Unknown protocol #{@host_param[:protocol]}"
        nil
      end
    end

    def load_prompt_regexp
      prompt_file = "#{prompts_dir}/#{@host_param[:type]}_prompt.yml"
      File.file?(prompt_file) ? YAML.load_file(prompt_file) : nil
    end

    def setup_default_logger(logger_io)
      @logger = Logger.new(logger_io)
      @logger.level = Logger::INFO
      @logger.progname = 'Expectacle'
      @logger.datetime_format = '%Y-%m-%d %H:%M:%D %Z'
      @logger.formatter = proc do |severity, datetime, progname, msg|
        "#{datetime} #{progname} [#{severity}] #{msg}\n"
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

    def embed_password(binding)
      base_str = @enable_mode ? @host_param[:enable] : @host_param[:password]
      check_embed_envvar(base_str)
      passwd_erb = ERB.new(base_str)
      passwd_erb.result(binding)
    end

    def embed_command(command, binding)
      command_erb = ERB.new(command)
      command_erb.result(binding)
    end

    def embed_user_name(binding)
      check_embed_envvar(@host_param[:username])
      uname_erb = ERB.new(@host_param[:username])
      uname_erb.result(binding)
    end
  end
end
