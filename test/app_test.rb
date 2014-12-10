require 'GeneValidatorApp'
require 'rack/test'

module GeneValidatorApp
  decribe 'App' do
    ENV['RACK_ENV'] = 'test'
    include Rack::Test::Methods

    let 'root' do
      GeneValidatorApp.root
    end

    let 'empty_config' do 
      Pathname.new(root) + 'spec' + 'empty_config.yml'
    end

    let 'database_dir' do
      Pathname.new(root) + 'spec' + 'database'
    end

    let 'app' do
      GeneValidatorApp.init(:config_file => empty_config,
                            :database_dir => database_dir§)
    end

    before :each do
      app
      @params { 'seqs' => 'AGCTAGCTAGCT'
                'vals' => ''}

    end

    
  end
end