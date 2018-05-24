# frozen_string_literal: true

require 'expectacle/thrower_preview'
require 'expectacle/thrower_utils'

module Expectacle
  # Thrower logic(command list operation)
  class Thrower < ThrowerBase
    # #run_command_for_all_host [for hosts]
    #   - initialize command list (`@commands`)
    #     and host params (`@host_param`)
    #   #run_command_for_host [for a host]  #-> thrower_base
    #     ...
    #       #exec_each_prompt #-> override

    # Run(exec) commands for all hosts.
    # @param [Array<Hash>] hosts Host parameters (read from host list file).
    # @param [Array<String>] commands Commands (read from command list file).
    def run_command_for_all_hosts(hosts, commands)
      hosts.each do |each|
        @commands = commands.dup # Notice: @commands will be decremented.
        @commands_len = @commands.length
        @host_param = each
        clear_auth_count
        run_command_for_host
      end
    end

    private

    # Send command when found prompt
    # @param prompt [String] Prompt
    def exec_each_prompt(prompt)
      check_auth_count
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

    # Send command according to exec mode
    # @param prompt [String] Prompt
    def exec_by_mode(prompt)
      case prompt
      when /#{@prompt[:command2]}/
        exec_in_privilege_mode
      when /#{@prompt[:command1]}/
        exec_in_normal_mode
      end
    end

    # Send command in priviledge mode
    def exec_in_privilege_mode
      exec_rest_commands do
        # Notice: @commands changed
        command = @commands.shift
        write_and_logging 'Send command: ', embed_command(command)
      end
    end

    # Send command in normal (non-priviledge) mode
    def exec_in_normal_mode
      exec_rest_commands do
        write_and_logging 'Send enable command: ', @prompt[:enable_command]
        @enable_mode = true
      end
    end

    # Check command list is empty or not.
    # If command list is empty, then close session
    # @yield [] Operations when command list is not empty
    def exec_rest_commands
      if !@commands.empty?
        yield
      else
        close_session
      end
    end

    # Send command in sub-prompt
    # @param prompt [String] Prompt
    def exec_by_sub_prompt(prompt)
      case prompt
      when /#{@prompt[:yn]}/
        # it must match before sub_prompt
        write_and_logging 'Send yes: ', 'yes'
      when /#{@prompt[:sub1]}/, /#{@prompt[:sub2]}/
        write_and_logging 'Send return: ', ''
      end
    end
  end
end
