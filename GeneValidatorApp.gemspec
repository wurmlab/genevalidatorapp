# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'GeneValidatorApp/version'

Gem::Specification.new do |spec|
  spec.name          = 'GeneValidatorApp'
  spec.version       = GeneValidatorApp::VERSION
  spec.authors       = ['Ismail Moghul']
  spec.email         = ['Ismail.Moghul@gmail.com']
  spec.summary       = 'A Web App wrapper for GeneValidator.'
  spec.description   = 'A Web App wrapper for GeneValidator, a program for validating gene predictions.'
  spec.homepage      = 'https://github.com/IsmailM/GeneValidatorApp'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.6'
  spec.add_development_dependency 'rake', '~>10.3'
  spec.add_dependency 'sinatra', '~>1.4'
  spec.add_dependency 'sinatra-contrib', '~>1.4'
  spec.add_dependency 'bio', '~>1.4'
  spec.add_dependency 'slim', '~>2.0'
  spec.add_dependency 'GeneValidator', '~>1.1'
end
