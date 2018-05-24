# frozen_string_literal: true

require 'pty'
require 'expect'
require 'expectacle/thrower_base_io'
require 'expectacle/thrower_base_params'

module Expectacle
  # Basic state setup/management
  class ThrowerBase
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

    private

    # #run_command_for_host [for a host]
    #   #ready_to_open_host_session
    #     - initialize prompts (`@prompt`), `spawn_cmd` string
    #     #open_interactive_process
    #       - spawn and setup @reader/@writer
    #       #run_command
    #         #do_on_interactive_process
    #           - expect
    #           #exec_each_prompt (will be overriden)

    # Run(Send) command to host(interactive process)
    def run_command_for_host
      ready_to_open_host_session do |spawn_cmd|
        open_interactive_process(spawn_cmd) do
          before_run_command
          run_command
        end
      end
    end

    # Setup a parameters for interactive process
    # @yield [spawn_cmd] Operations for interactive process
    # @yieldparam spawn_cmd [String] Command of interactive process
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

    # Spawn interactive process
    # @yield [] Operations for interactive process
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

    # Pre-process before send command
    def before_run_command
      return unless @local_serial
      # for `cu` command
      @reader.expect(/^Connected\./, 1) do
        write_and_logging 'Send enter to connect serial', "\r\n", true
      end
    end

    # Send command to host(interactive process)
    def run_command
      do_on_interactive_process do |match|
        @logger.debug "Read: #{match}"
        exec_each_prompt match[1]
      end
    end

    # Search prompt and send command, while process is opened
    # @yield [match] Send operations when found prompt
    # @yieldparam match [String] Expect matches string (prompt)
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

    # Send command when found prompt
    # @abstract Subclass must override to send command (per prompt)
    # @param _prompt [String] Prompt
    # @raise [Error]
    def exec_each_prompt(_prompt)
      raise 'Called abstract method'
    end
  end
end
