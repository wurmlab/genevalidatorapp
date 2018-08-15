require 'minitest/autorun'
require 'capybara/minitest'

require 'genevalidatorapp'

# Basic unit tests for HTTP / Rack interface.
module GeneValidatorApp
  # include W3CValidators
  describe 'Routes' do
    ENV['RACK_ENV'] = 'production'
    include Rack::Test::Methods

    let 'root' do
      GeneValidatorApp.root
    end

    let 'empty_config' do
      File.join(root, 'test', 'empty_config.yml')
    end

    let 'database_dir' do
      File.join(root, 'test', 'database')
    end

    before :each do
      GeneValidatorApp.init(config_file: empty_config,
                            database_dir: database_dir)

      validations = %w[lenc lenr dup merge align frame orf]
      sequence    = 'AGCTAGCTAGCT'
      database    = Database.first.name

      @params = {
        'validations' => validations,
        'seq'         => sequence,
        'database'    => database
      }
    end

    let 'app' do
      GeneValidatorApp
    end

    it 'should start the app' do
      get '/'
      assert_equal(true, last_response.ok?)
    end

    it 'returns Bad Request (400) if no sequence is provided' do
      @params.delete('seq')
      post '/', @params
      assert_equal(400, last_response.status)
    end

    it 'returns Bad Request (400) if no validations is provided' do
      @params.delete('validations')
      post '/', @params
      assert_equal(400, last_response.status)
    end

    it 'returns Bad Request (400) if no database is provided' do
      @params.delete('database')
      post '/', @params
      assert_equal(400, last_response.status)
    end

    # W3C_Validator Gem is broken - https://github.com/alexdunae/w3c_validators/issues/16
    # it 'validate the html' do
    # get '/'
    # html = last_response.body

    # validator = MarkupValidator.new
    # results = validator.validate_text(html.to_s)
    # results.errors.each { |err| puts err.to_s } if results.errors.length > 0
    # puts results.errors
    # results.errors.length.should == 0
    # end
  end
end
