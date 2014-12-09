require 'GeneValidatorApp/database'
require 'GeneValidatorApp/genevalidator'
require 'GeneValidatorApp/logger'

require 'pathname'
require 'yaml'
require 'sinatra/base'
require 'sinatra/cross_origin'
require 'slim'
require 'thin'

module GeneValidatorApp
  # Use a fixed minimum version of BLAST+
  MINIMUM_BLAST_VERSION           = '2.2.29+'
  MINIMUM_GV_VERSION              = '0.1'
  # Use the following exit codes, or 1.
  EXIT_BLAST_NOT_INSTALLED        = 2
  EXIT_BLAST_NOT_COMPATIBLE       = 3
  EXIT_NO_BLAST_DATABASE          = 4
  EXIT_BLAST_INSTALLATION_FAILED  = 5
  EXIT_CONFIG_FILE_NOT_FOUND      = 6
  EXIT_NO_SEQUENCE_DIR            = 7

  class << self
    attr_reader :config_file, :config, :public_dir, :tempdir

    def environment
      ENV['RACK_ENV']
    end

    def verbose?
      @verbose ||= (environment == 'development')
    end

    def logger
      @logger ||= Logger.new(STDERR, verbose?)
    end

    # This is the root dir of the App (contains views dir)
    def root
      Pathname.new(__FILE__).dirname.parent
    end

    def init(config = {})
      @config_file = config.delete(:config_file) || '~/.genevalidatorapp.conf'
      @config_file = File.expand_path(config_file)
      assert_file_present('config file', config_file, EXIT_CONFIG_FILE_NOT_FOUND)

      @config = {
        :num_threads  => 1,
        :port         => 4567,
        :host         => 'localhost',
        :web_dir      => Pathname.pwd
      }.update(parse_config_file.merge(config))

      assert_genevalidator_installed_and_compatible

      if @config[:blast_bin]
        @config[:blast_bin] = File.expand_path @config[:blast_bin]
        assert_dir_present('BLAST bin dir', @config[:blast_bin])
        export_bin_dir(@config[:blast_bin])
      end

      assert_blast_installed_and_compatible

      if @config[:mafft_bin]
        @config[:mafft_bin] = File.expand_path @config[:mafft_bin]
        assert_dir_present('Mafft bin dir', @config[:mafft_bin])
        export_bin_dir(@config[:mafft_bin])
      end

      # assert_mafft_installed_and_compatible

      assert_dir_present('database dir', @config[:database_dir], EXIT_NO_SEQUENCE_DIR)
      @config[:database_dir] = File.expand_path(@config[:database_dir])
      assert_blast_databases_present_in_database_dir

      Database.scan_databases_dir
      #  Check if the Database contains the default database - warn if not present
      #  Ensure that there is at least one Database

      @config[:num_threads] = Integer(@config[:num_threads])
      assert_num_threads_valid @config[:num_threads]
      logger.debug("Will use #{@config[:num_threads]} threads to run BLAST.")

      if @config[:require]
        @config[:require] = File.expand_path @config[:require]
        assert_file_present 'extension file', @config[:require]
        require @config[:require]
      end

      set_up_gv_tempdir
      set_up_public_folder
    end

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

    def max_characters
      (config[:max_characters]) ? config[:max_characters].to_i : 'undefined'
    end

    def current_gv_version
      %x(genevalidator --version)
    end

    def [](key)
      config[key]
    end

    # Rack-interface.
    #
    # Inject our logger in the env and dispatch request to our
    # controller.
    def call(env)
      env['rack.logger'] = logger
      App.call(env)
    end

    private

    # This is the folder in which
    def set_up_public_folder
      @public_dir = Pathname.new(config[:web_dir]) + "GeneValidator_#{Time.now.strftime('%Y%m%d-%H%M%S')}"
      root_public_dir = GeneValidatorApp.root + 'public'
      FileUtils.cp_r(root_public_dir, @public_dir)
    end

    # This is a temp directory
    def set_up_gv_tempdir
      @tempdir = Pathname.new(Dir.mktmpdir('GeneValidator_'))
    end

    def parse_config_file
      # logger.debug("Reading configuration file: #{@config_file}.")
      config = YAML.load_file(config_file) || {}
      config.inject({}){|c, e| c[e.first.to_sym] = e.last; c}
    rescue ArgumentError => error
      puts "*** Error in config file: #{error}."
      puts "    YAML is white space sensitive. Is your config file properly indented?"
      exit 1
    end

    def write_config_file
      File.open(GeneValidatorApp.config_file, 'w') do |f|
        f.puts(config.delete_if{|k, v| v.nil?}.to_yaml)
      end
    end

    # Export bin dir to PATH environment variable.
    def export_bin_dir(dir)
      bin_dir = File.expand_path(dir)
      if bin_dir
        unless ENV['PATH'].split(':').include? bin_dir
          ENV['PATH'] = "#{bin_dir}:#{ENV['PATH']}"
        end
      end
    end

    def assert_file_present(desc, file, exit_code = 1)
      unless file and File.exists?( File.expand_path(file) )
        puts "*** Couldn't find #{desc}: #{file}."
        exit exit_code
      end
    end

    alias assert_dir_present assert_file_present

    def assert_blast_installed_and_compatible
      unless command? 'blastdbcmd'
        puts "*** Could not find BLAST+ binaries."
        exit EXIT_BLAST_NOT_INSTALLED
      end
      version = %x|blastdbcmd -version|.split[1]
      unless version >= MINIMUM_BLAST_VERSION
        puts "*** Your BLAST+ version #{version} is outdated."
        puts "    SequenceServer needs NCBI BLAST+ version #{MINIMUM_BLAST_VERSION} or higher."
        exit EXIT_BLAST_NOT_COMPATIBLE
      end
    end

    def assert_blast_databases_present_in_database_dir
      database_dir = config[:database_dir]
      out = %x|blastdbcmd -recursive -list #{database_dir}|
      if out.empty?
        puts "*** Could not find BLAST databases in '#{database_dir}'."
        exit EXIT_NO_BLAST_DATABASE
      elsif out.match(/BLAST Database error/) or not $?.success?
        puts "*** Error obtaining BLAST databases."
        puts "    Tried: #{find_dbs_command}"
        puts "    Error:"
        out.strip.split("\n").each do |l|
          puts "      #{l}"
        end
        puts "    Please could you report this to 'https://groups.google.com/forum/#!forum/sequenceserver'?"
        exit EXIT_BLAST_DATABASE_ERROR
      end
    end

    def assert_num_threads_valid num_threads
      unless num_threads > 0
        puts "*** Can't use #{num_threads} number of threads."
        puts "    Number of threads should be greater than or equal to 1."
        exit 1
      end
      if num_threads > 256
        logger.warn "*** Number of threads set at #{num_threads} is unusually high."
      end
    rescue
      puts "*** Number of threads should be a number."
      exit 1
    end

    def assert_genevalidator_installed_and_compatible
      unless command? 'genevalidator'
        puts "*** GeneValidator is not installed."
        exit 1
      end
      version = GeneValidatorApp.current_gv_version
      unless version >= MINIMUM_GV_VERSION
        puts "*** Your GeneValidator (version #{version}) is outdated."
        puts "    GeneValidatorApp requires GeneValidator version #{MINIMUM_GV_VERSION} or higher."
        exit 1
      end
    end

    # Return `true` if the given command exists and is executable.
    def command?(command)
      system("which #{command} > /dev/null 2>&1")
    end
  end
  

  # The Actual App...
  class App < Sinatra::Base
    register Sinatra::CrossOrigin
    configure do
      # We don't need Rack::MethodOverride. Let's avoid the overhead.
      disable :method_override

      # Ensure exceptions never leak out of the app. Exceptions raised within
      # the app must be handled by the app. We do this by attaching error
      # blocks to exceptions we know how to handle and attaching to Exception
      # as fallback.
      disable :show_exceptions, :raise_errors

      # Make it a policy to dump to 'rack.errors' any exception raised by the
      # app so that error handlers don't have to do it themselves. But for it
      # to always work, Exceptions defined by us should not respond to `code`
      # or http_status` methods. Error blocks errors must explicitly set http
      # status, if needed, by calling `status` method.
      # method.
      enable  :dump_errors

      # We don't want Sinatra do setup any loggers for us. We will use our own.
      set :logging, nil

      # This is the app root...
      set :root,    lambda { GeneValidatorApp.root }

      # This is the full path to the public folder...
      set :public_folder, lambda { GeneValidatorApp.public_dir }

      # Required for GVAPP-API to work...
      enable :cross_origin
    end

    not_found do
      status 404
      slim :"500"
    end

    error do
      slim :"500", layout: false
    end

    # Set up global variables for the templates...
    before '/' do
      @default_db         = Database.default_db
      @non_default_dbs    = Database.non_default_dbs
      @max_characters     = GeneValidatorApp.max_characters
      @current_gv_version = GeneValidatorApp.current_gv_version
    end

    get '/' do
      slim :index
    end

    post '/input' do
      GeneValidator.init
      GeneValidator.run(params, request.url)
    end
  end
end