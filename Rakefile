require 'bundler/gem_tasks'

task :default => [:build]

desc "Installs the ruby gem"
task :build do
  exec("gem build GeneValidatorApp.gemspec && gem install ./GeneValidatorApp-#{GeneValidatorApp::VERSION}.gem")
end
