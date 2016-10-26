require 'bundler/gem_tasks'
task default: [:spec, :rubocop]

begin
  require 'rspec/core/rake_task'
  RSpec::Core::RakeTask.new
rescue LoadError
  task :spec do
    $stderr.puts 'RSpec is disabled'
  end
end

begin
  require 'rubocop/rake_task'
  RuboCop::RakeTask.new
rescue LoadError
  task :rubocop do
    $stderr.puts 'RuboCop is disabled'
  end
end
