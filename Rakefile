require 'rake/testtask'
GEMSPEC = Gem::Specification::load('genevalidatorapp.gemspec')

task default: [:build]

desc 'Builds and installs'
task install: [:build] do
  sh "gem install #{Rake.original_dir}/genevalidatorapp-#{GEMSPEC.version}.gem"
end

desc 'Runs tests and builds gem (default)'
task build: [:test] do
  sh "gem build #{Rake.original_dir}/genevalidatorapp.gemspec"
end

desc 'Runs tests'
task :test do
  Rake::TestTask.new do |t|
    t.libs.push 'lib'
    t.test_files = FileList['test/test_*.rb']
    t.verbose = false
    t.warning = false
  end
end
