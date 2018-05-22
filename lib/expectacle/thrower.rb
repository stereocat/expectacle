# frozen_string_literal: true

require 'expectacle/thrower_base'

module Expectacle
  # Thrower logic(command list operation)
  class Thrower < ThrowerBase
    # Run(exec) commands for all hosts.
    # @param [Array<Hash>] hosts Host parameters (read from host list file).
    # @param [Array<String>] commands Commands (read from command list file).
    def run_command_for_all_hosts(hosts, commands)
      hosts.each do |each|
        @commands = commands.dup # Notice: @commands will be decremented.
        @host_param = each
        run_command_for_host
      end
    end

    # Preview all parameters for all hosts.
    # @param [Array<Hash>] hosts Host parameters (read from host list file).
    # @param [Array<String>] commands Commands (read from command list file).
    def preview_parameter(hosts, commands)
      print YAML.dump(previewed_data(hosts, commands))
    end

    # Preview all parameters for all hosts (for testing)
    # @param [Array<Hash>] hosts Host parameters (read from host list file).
    # @param [Array<String>] commands Commands (read from command list file).
    def previewed_data(hosts, commands)
      @commands = commands
      hosts.map do |each|
        @host_param = each
        preview_command_for_host
      end
    end

    private

    def run_command_for_host
      ready_to_open_host_session do |spawn_cmd|
        open_interactive_process(spawn_cmd) do
          before_run_command
          run_command
        end
      end
    end

    def preview_command_for_host
      ready_to_open_host_session do |spawn_cmd|
        whole_previewed_parameters(spawn_cmd)
      end
    end

    def before_run_command
      return unless @local_serial
      # for `cu` command
      @reader.expect(/^Connected\./, 1) do
        write_and_logging 'Send enter to connect serial', "\r\n", true
      end
    end

    def run_command
      do_on_interactive_process do |match|
        @logger.debug "Read: #{match}"
        exec_each_prompt match[1]
      end
    end

    def previewed_host_param
      host_param = @host_param.dup
      enable_mode = @enable_mode
      @enable_mode = false
      host_param[:username] = embed_user_name
      host_param[:password] = embed_password
      @enable_mode = true
      host_param[:enable] = embed_password
      @enable_mode = enable_mode
      host_param
    end

    def previewed_commands
      @commands.map { |cmd| embed_command(cmd) }
    end

    def whole_previewed_parameters(spawn_cmd)
      {
        spawn_cmd: spawn_cmd,
        prompt: @prompt,
        host: previewed_host_param,
        commands: previewed_commands
      }
    end

    def exec_rest_commands
      if !@commands.empty?
        yield
      else
        write_and_logging 'Send break: ', 'exit'
        if @local_serial
          # write_and_logging 'Disconnect: ', @serial_exit
          @logger.info 'Close IO for spawn command'
          @reader.close
          @writer.close
        end
      end
    end

    def exec_in_privilege_mode
      exec_rest_commands do
        # Notice: @commands changed
        command = @commands.shift
        write_and_logging 'Send command: ', embed_command(command)
      end
    end

    def exec_in_normal_mode
      exec_rest_commands do
        write_and_logging 'Send enable command: ', @prompt[:enable_command]
        @enable_mode = true
      end
    end

    def exec_by_mode(prompt)
      case prompt
      when /#{@prompt[:command2]}/
        exec_in_privilege_mode
      when /#{@prompt[:command1]}/
        exec_in_normal_mode
      end
    end

    def exec_by_sub_prompt(prompt)
      case prompt
      when /#{@prompt[:yn]}/
        # it must match before sub_prompt
        write_and_logging 'Send yes: ', 'yes'
      when /#{@prompt[:sub1]}/, /#{@prompt[:sub2]}/
        write_and_logging 'Send return: ', ''
      end
    end

    def exec_each_prompt(prompt)
      case prompt
      when /#{@prompt[:password]}/, /#{@prompt[:enable_password]}/
        write_and_logging 'Send password', embed_password, true
      when /#{@prompt[:username]}/
        write_and_logging 'Send username: ', embed_user_name
      when /#{@prompt[:command2]}/, /#{@prompt[:command1]}/
        exec_by_mode(prompt)
      when /#{@prompt[:yn]}/, /#{@prompt[:sub1]}/, /#{@prompt[:sub2]}/
        exec_by_sub_prompt(prompt)
      else
        @logger.error "Unknown prompt #{prompt}"
      end
    end
  end
end
