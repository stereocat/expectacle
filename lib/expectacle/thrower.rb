# frozen_string_literal: true

require 'expectacle/thrower_base'

module Expectacle
  # Thrower logic(command list operation)
  class Thrower < ThrowerBase
    def run_command_for_all_hosts(hosts, commands)
      @commands = commands
      hosts.each do |each|
        @host_param = each
        run_command_for_host
      end
    end

    def preview_parameter(hosts, commands)
      @commands = commands
      hosts.each do |each|
        @host_param = each
        preview_command_for_host
      end
    end

    private

    def run_command_for_host
      ready_to_open_host_session do |spawn_cmd|
        open_interactive_process(spawn_cmd) do
          run_command
        end
      end
    end

    def preview_command_for_host
      ready_to_open_host_session do |spawn_cmd|
        preview_command spawn_cmd
      end
    end

    def run_command
      do_on_interactive_process do |match|
        @logger.debug "Read: #{match}"
        exec_each_prompt match[1]
      end
    end

    def preview_host_param
      host_param = @host_param.dup
      enable_mode = @enable_mode
      @enable_mode = false
      host_param[:username] = embed_user_name(binding)
      host_param[:password] = embed_password(binding)
      @enable_mode = true
      host_param[:enable] = embed_password(binding)
      @enable_mode = enable_mode
      host_param
    end

    def preview_commands
      @commands.map { |cmd| embed_command(cmd, binding) }
    end

    def preview_command(spawn_cmd)
      data = {}
      data[:spawn_cmd] = spawn_cmd
      data[:prompt] = @prompt
      data[:host] = preview_host_param
      data[:commands] = preview_commands
      print YAML.dump(data)
    end

    def exec_rest_commands
      if !@commands.empty?
        yield
      else
        write_and_logging 'Send break: ', 'exit'
      end
    end

    def exec_in_privilege_mode
      exec_rest_commands do
        # Notice: @commands changed
        command = @commands.shift
        write_and_logging 'Send command: ', embed_command(command, binding)
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
        write_and_logging 'Send password', embed_password(binding), true
      when /#{@prompt[:username]}/
        write_and_logging 'Send username: ', embed_user_name(binding)
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
