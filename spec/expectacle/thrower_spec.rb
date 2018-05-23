require 'rspec/given'
require 'expectacle/thrower'

module Expectacle
  describe Thrower do
    describe '.new' do
      Given(:thrower) { Thrower.new }

      describe '#prompts_dir' do
        When(:prompts_dir) { thrower.prompts_dir }
        Then { prompts_dir == File.join(thrower.base_dir, 'prompts') }
      end

      describe '#hosts_dir' do
        When(:hosts_dir) { thrower.hosts_dir }
        Then { hosts_dir == File.join(thrower.base_dir, 'hosts') }
      end

      describe '#commands_dir' do
        When(:commands_dir) { thrower.commands_dir }
        Then { commands_dir == File.join(thrower.base_dir, 'commands') }
      end

      describe '#opts_dir' do
        When(:opts_dir) { thrower.opts_dir }
        Then { opts_dir == File.join(thrower.base_dir, 'opts') }
      end
    end
  end
end
