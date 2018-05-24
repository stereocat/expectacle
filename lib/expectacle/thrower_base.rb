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
  end
end
