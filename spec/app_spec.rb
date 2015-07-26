require 'genevalidatorapp'
require 'rack/test'
require 'w3c_validators'

module GeneValidatorApp
  include W3CValidators

  describe 'App' do
    ENV['RACK_ENV'] = 'test'
    include Rack::Test::Methods

    let 'root' do
      GeneValidatorApp.root
    end

    let 'empty_config' do
      File.join(root, 'spec', 'empty_config.yml')
    end

    let 'database_dir' do
      File.join(root, 'spec', 'database')
    end

    let 'app' do
      GeneValidatorApp.init(config_file: empty_config,
                            database_dir: database_dir)
    end

    before :each do
      app
      @params = { 'seq'         => 'AGCTAGCTAGCT',
                  'validations' => '["lenc", "lenr", "dup", "merge", "align", "frame", "orf"]',
                  'database'    => Database.first.name }
    end

    it 'should start the app' do
      get '/'
      last_response.ok?.should == true
    end

    it 'returns Bad Request (400) if no sequence is provided' do
      @params.delete('seq')
      post '/input', @params
      last_response.status.should == 400
    end

    it 'returns Bad Request (400) if no validations is provided' do
      @params.delete('validations')
      post '/input', @params
      last_response.status.should == 400
    end

    it 'returns Bad Request (400) if no database is provided' do
      @params.delete('database')
      post '/input', @params
      last_response.status.should == 400
    end

    it 'returns OK (200) when sequence, validations and database name are provided' do
      post '/input', @params
      last_response.status.should == 200

      @params[:result_link] = 'yes'
      post '/input', @params
      last_response.status.should == 200
    end

    it 'returns not found (404) when random url is posted against' do
      post '/not_a_real_url', @params
      last_response.status.should == 404
    end

    it 'validate the html' do
      get '/'
      html = last_response.body

      validator = MarkupValidator.new
      r = validator.validate_text(html)

      if r.errors.length > 0
        r.errors.each do |err|
          puts err.to_s
        end
        results = false
      else
        results = true
      end
      results.should == true
    end

    # it 'should validate the css' do
    #   css = File.read(File.join(root, 'public/web_files/css/custom.min.css'))
    #   validator = CSSValidator.new
    #   r = validator.validate_text(css)

    #   if r.errors.length > 0
    #     r.errors.each do |err|
    #       puts err.to_s
    #     end
    #     results = false
    #   else
    #     results = true
    #   end
    #   results.should == true
    # end
  end
end
