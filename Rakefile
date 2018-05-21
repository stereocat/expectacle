require 'bundler/gem_tasks'
task default: %i[spec rubocop]

begin
  require 'rspec/core/rake_task'
  RSpec::Core::RakeTask.new
rescue LoadError
  task :spec do
    warn 'RSpec is disabled'
  end
end

begin
  require 'rubocop/rake_task'
  RuboCop::RakeTask.new
rescue LoadError
  task :rubocop do
    warn 'RuboCop is disabled'
  end
end

begin
  require 'yard'
  require 'yard/rake/yardoc_task'
  YARD::Rake::YardocTask.new do |task|
    task.files = FileList['./lib/**/*.rb']
  end
rescue LoadError
  task :yard do
    warn 'YARD is disabled'
  end
end
