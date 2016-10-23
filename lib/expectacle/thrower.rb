# frozen_string_literal: true

require 'pty'
require 'expect'
require 'yaml'
require 'erb'
require 'logger'

module Expectacle
  class Thrower
    def initialize(timeout: 60, verbose: true, base_dir: '', logger: $stdout)
      # remote connection timeout (sec)
      @timeout = timeout
      # cli mode flag
      @enable_mode = false
      # debug (use debug print to stdout)
      $expect_verbose = verbose
      # base dir
      @base_dir = File.expand_path(__dir__ + base_dir)
      # logger
      @logger = Logger.new(logger)
      setup_logger
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

    def run_command_for_all_hosts(host_list_file, command_list_file)
      # host list to send commands
      @host_list = YAML.load_file("#{hosts_dir}/#{host_list_file}")

      @host_list.each do |host_param|
        @host_param = host_param
        run_command_for_host command_list_file
      end
    end

    private

    def run_command_for_host(command_list_file)
      # prompt regexp of device
      @prompt = load_prompt_regexp
      spawn_cmd = make_spawn_command
      if @prompt && spawn_cmd
        spawn_interactive_process spawn_cmd, command_list_file
      else
        @logger.error 'Invalid parameter in param file(S)'
      end
    end

    def setup_logger
      @logger.level = Logger::INFO
      @logger.progname = 'Expectacle'
      @logger.datetime_format = '%Y-%m-%d %H:%M:%D %Z'
      @logger.formatter = proc {|severity, datetime, progname, msg| "#{datetime} #{progname} [#{severity}] #{msg}\n"}
    end

    def load_prompt_regexp
      prompt_file = "#{prompts_dir}/#{@host_param[:type]}_prompt.yml"
      File.file?(prompt_file) ? YAML.load_file(prompt_file) : nil
    end

    def spawn_interactive_process(spawn_cmd, command_list_file)
      @logger.info "Begin spawn: #{spawn_cmd}"
      PTY.spawn(spawn_cmd) do |reader, writer, _pid|
        @enable_mode = false
        @reader = reader
        @writer = writer
        run_command command_list_file
      end
      @logger.info "End spawn: #{@host_param[:hostname]}"
    end

    def run_command(command_list_file)
      @writer.sync = true
      cmd_list = YAML.load_file("#{commands_dir}/#{command_list_file}")
      begin
        until @reader.eof?
          @reader.expect(expect_regexp, @timeout) do |match|
            exec_each_prompt match[1], cmd_list
          end
        end
      rescue Errno::EIO => _
        # NO-OP: when process exit (on linux)
      ensure
        # Process.wait pid
      end
    end

    def embed_user_name(binding)
      uname_erb = ERB.new(@host_param[:username])
      uname_erb.result(binding)
    end

    def embed_password(binding)
      base_str = @enable_mode ? @host_param[:enable] : @host_param[:password]
      passwd_erb = ERB.new(base_str)
      passwd_erb.result(binding)
    end

    def embed_command(command, binding)
      command_erb = ERB.new(command)
      command_erb.result(binding)
    end

    def make_spawn_command
      case @host_param[:protocol]
        when /^telnet$/i
          ['telnet', @host_param[:ipaddr]].join(' ')
        when /^ssh$/i
          ['ssh',
           '-o StrictHostKeyChecking=no',
           '-o KexAlgorithms=+diffie-hellman-group1-sha1', # for old cisco device
           '-l', embed_user_name(binding),
           @host_param[:ipaddr]].join(' ')
        else
          @logger.error "Unknown protocol #{@host_param[:protocol]}"
          nil
      end
    end

    def expect_regexp
      %r!
        ( #{@prompt[:password]} | #{@prompt[:enable_password]}
        | #{@prompt[:username]}
        | #{@prompt[:command1]} | #{@prompt[:command2]}
        | #{@prompt[:sub1]} | #{@prompt[:sub2]}
        | #{@prompt[:yn]}
        )\s*$
      !x
    end

    def write_and_logging(message, command, secret=false)
      logging_message = secret ? message : message + command
      @logger.info logging_message
      @writer.puts command
    end

    def exec_each_prompt(prompt, cmd_list)
      case prompt
        when /#{@prompt[:password]}/, /#{@prompt[:enable_password]}/
          write_and_logging 'Send password', embed_password(binding), true
        when /#{@prompt[:username]}/
          write_and_logging 'Send username: ', embed_user_name(binding)
        when /#{@prompt[:command2]}/
          if cmd_list.length > 0
            # Notice `cmd_list` was changed
            write_and_logging 'Send command: ', embed_command(cmd_list.shift, binding)
          else
            write_and_logging 'Send break: ', 'exit'
          end
        when /#{@prompt[:command1]}/
          if cmd_list.length > 0
            write_and_logging 'Send enable command: ', @prompt[:enable_command]
            @enable_mode = true
          else
            write_and_logging 'Send break: ', 'exit'
          end
        when /#{@prompt[:yn]}/
          # it must match before sub_prompt
          write_and_logging 'Send yes: ', 'yes'
        when /#{@prompt[:sub1]}/, /#{@prompt[:sub2]}/
          write_and_logging 'Send return: ', ''
        else
          @logger.error "Unknown prompt #{prompt}"
      end
    end
  end
end
