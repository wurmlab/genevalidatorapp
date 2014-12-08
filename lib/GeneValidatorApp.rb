require 'GeneValidatorApp/GeneValidatorAppHelper.rb'
require 'pathname'
require 'slim'
require 'sinatra/base'
require 'sinatra/config_file'

module GeneValidatorApp
  # Use a fixed minimum version of BLAST+
  MINIMUM_BLAST_VERSION           = '2.2.27+'
  # Use the following exit codes, or 1.
  EXIT_BLAST_NOT_INSTALLED        = 2
  EXIT_BLAST_NOT_COMPATIBLE       = 3
  EXIT_NO_BLAST_DATABASE          = 4
  EXIT_BLAST_INSTALLATION_FAILED  = 5
  EXIT_CONFIG_FILE_NOT_FOUND      = 6
  EXIT_NO_SEQUENCE_DIR            = 7

  class << self

    def init(config = {})
      @config_file = config.delete(:config_file) || '~/.genevalidatorapp.conf'
      @config_file = File.expand_path(config_file)
      assert_file_present('config file', config_file, EXIT_CONFIG_FILE_NOT_FOUND)      

      @config = {
        :num_threads  => 1,
        :port         => 4567,
        :host         => 'localhost'
      }.update(parse_config_file.merge(config))
    




    end

    attr_reader :config_file, :config

    def run
      url = "http://#{config[:host]}:#{config[:port]}"
      server = Thin::Server.new(config[:host], config[:port], :signals => false) do
        use Rack::CommonLogger
        run GeneValidatorApp
      end
      server.silent = true
      server.backend.start do
        puts "** GeneValidatorApp is ready."
        puts "   Go to #{url} in your browser and start analysing Genes!"
        puts "   Press CTRL+C to quit."
        [:INT, :TERM].each do |sig|
          trap sig do
            server.stop!
            puts
            puts "** Thank you for using GeneValidatorApp :)."
            puts "   Please cite: "
            puts "             Dragan M., Moghul M.I., Priyam A., Wurm Y (in prep)."
            puts "             GeneValidator: identify problematic gene predictions."
          end
        end
      end
    rescue
      puts "** Oops! There was an error."
      puts "   Is GeneValidatorApp already accessible at #{url}?"
      puts "   Try running GeneValidatorApp on another port, like so: genevalidatorapp -p 4570."
    end

    private

    def parse_config_file
      # logger.debug("Reading configuration file: #{@config_file}.")
      config = YAML.load_file(config_file) || {}
      config.inject({}){|c, e| c[e.first.to_sym] = e.last; c}
    rescue ArgumentError => error
      puts "*** Error in config file: #{error}."
      puts "YAML is white space sensitive. Is your config file properly indented?"
      exit 1
    end

    def assert_file_present desc, file, exit_code = 1
      unless file and File.exists? File.expand_path file
        puts "*** Couldn't find #{desc}: #{file}."
        exit exit_code
      end
    end
  end

  # The Actual App...
  class App < Sinatra::Base
    helpers GeneValidatorAppHelper

    configure do
      register Sinatra::ConfigFile
      config_file "#{Pathname.new(__FILE__).dirname.parent + 'config.yml'}"
    end
    
    not_found do
      status 404
      slim :"500"
    end
    
    error do
      slim :"500", layout: false
    end

    # Sert up variables for the templates
    before '/' do 
      @default_db      = settings.default_db
      @non_default_dbs = settings.non_default
      @GVversion       = settings.GVversion
      @maxCharacters   = settings.maxCharacters
    end

    get '/' do
      slim :index
    end

    options '/post' do
      response.headers["Access-Control-Allow-Origin"] = "*"
      response.headers["Access-Control-Allow-Methods"] = "POST"

      halt 200
    end

    # Run only when submitting a job to the server.
    before '/input' do
      @tempdir         = settings.tempdir
      @dbs             = settings.dbs
      @unique_name     = create_unique_name

      # Public Folder = folder that is served to the web app
      # By default, the folder is created in the Current Working Directory...
      @public_folder   = settings.public_folder + 'GeneValidator' + @unique_name

      # The Working directory created within the tempdir..
      @working_dir     = @tempdir + @unique_name
      if File.exist?(@working_dir)
        @unique_name   = ensure_unique_name(@working_dir, @tempdir)
      end
      
      FileUtils.mkdir_p @working_dir
      FileUtils.ln_s "#{@working_dir}", "#{@public_folder}"
    end

    post '/input' do
      seqs      = params[:seq]
      vals      = params[:validations].to_s.gsub(/[\[\]\"]/, '')
      db_title  = params[:database]
      # Extracts the db path using the db title
      db_path   = @dbs.select { |_, v| v[0][:title] == db_title }.keys[0]

      sequences = clean_sequences(seqs, @working_dir)
      run_genevalidator(vals, db_path, seqs, @working_dir, @unique_name,
                        settings.mafft_path, settings.blast_path,
                        settings.num_threads, params[:result_link])
    end
  end
end