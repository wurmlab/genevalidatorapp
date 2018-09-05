require 'rake/testtask'
GEMSPEC = Gem::Specification.load('genevalidatorapp.gemspec')

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

desc 'Build Assets'
task :assets do
  # Requires uglifycss and uglifyjs
  # npm install uglifycss -g
  # npm install uglify-js -g
  src_assets_dir = File.expand_path('public/src', __dir__)
  assets_dir = File.expand_path('public/web_files', __dir__)
  `rm #{assets_dir}/css/gv.compiled.min.css`
  `rm #{assets_dir}/js/gv.compiled.min.js`
  sh "uglifycss --output '#{assets_dir}/css/gv.compiled.min.css'" \
    " '#{src_assets_dir}/css/bootstrap1.min.css'" \
    " '#{src_assets_dir}/css/font-awesome.min.css'" \
     " '#{src_assets_dir}/css/custom.css'"

  sh "uglifyjs '#{src_assets_dir}/js/jquery.min.js'" \
     " '#{src_assets_dir}/js/bootstrap.min.js'" \
     " '#{src_assets_dir}/js/jquery.tablesorter.min.js'" \
     " '#{src_assets_dir}/js/jquery.validate.min.js'" \
     " '#{src_assets_dir}/js/jquery.cookie.min.js'" \
     " '#{src_assets_dir}/js/d3.v3.min.js'" \
     " '#{src_assets_dir}/js/plots.js'" \
     " '#{src_assets_dir}/js/genevalidator.js'" \
     " -m -c -o '#{assets_dir}/js/gv.compiled.min.js'"
end
