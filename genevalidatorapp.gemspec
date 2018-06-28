# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'genevalidatorapp/version'

Gem::Specification.new do |s|
  s.name          = 'genevalidatorapp'
  s.version       = GeneValidatorApp::VERSION
  s.authors       = ['Monica Dragan', 'Ismail Moghul', 'Anurag Priyam',
                        'Yannick Wurm']
  s.email         = 'y.wurm@qmul.ac.uk'
  s.summary       = 'A Web App wrapper for GeneValidator.'
  s.description   = 'A Web App wrapper for GeneValidator, a program for' \
                       ' validating gene predictions.'
  s.homepage      = 'https://wurmlab.github.io/tools/genevalidator/'
  s.license       = 'AGPL'

  s.files         = `git ls-files -z`.split("\x0")
  s.executables   = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
  s.test_files    = s.files.grep(%r{^(test|spec|features)/})
  s.require_paths = ['lib']

  s.required_ruby_version = '>= 2.2.0'

  s.add_development_dependency 'bundler', '~> 1.6'
  s.add_development_dependency 'capybara', '~> 2.4', '>= 2.4.4'
  s.add_development_dependency 'minitest', '~> 5.10'
  s.add_development_dependency 'rake', '~> 12.3'
  # s.add_development_dependency 'w3c_validators', '~>1.1'

  s.add_dependency 'bio', '~>1.4'
  s.add_dependency 'sinatra', '~> 2.0'
  s.add_dependency 'sinatra-cross_origin', '~> 0.3'
  s.add_dependency 'slim', '~>3.0'
end
