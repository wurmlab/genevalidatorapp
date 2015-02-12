require 'GeneValidatorApp/database'
require 'GeneValidatorApp/genevalidator'
require 'GeneValidatorApp/logger'
require 'GeneValidatorApp/version'

require 'pathname'
require 'yaml'
require 'sinatra/base'
require 'sinatra/cross_origin'
require 'slim'
require 'thin'

module GeneValidatorApp
  # Use a fixed minimum version of BLAST+
  MINIMUM_BLAST_VERSION           = '2.2.29+'
  MINIMUM_GV_VERSION              = '0.1' # TODO: Correct me :)
  # Use the following exit codes, or 1.
  EXIT_BLAST_NOT_INSTALLED        = 2
  EXIT_BLAST_NOT_COMPATIBLE       = 3
  EXIT_NO_BLAST_DATABASE          = 4
  EXIT_BLAST_INSTALLATION_FAILED  = 5
  EXIT_CONFIG_FILE_NOT_FOUND      = 6
  EXIT_NO_SEQUENCE_DIR            = 7
  EXIT_GV_NOT_INSTALLED           = 8
  EXIT_GV_NOT_COMPATIBLE          = 9
  EXIT_MAFFT_NOT_INSTALLED        = 10

  class << self
    attr_reader :config_file, :config, :public_dir, :tempdir

    # Returns the Rack Environment
    def environment
      ENV['RACK_ENV']
    end

    def logger
      @logger ||= Logger.new(STDERR, verbose?)
    end

    # Root dir of the App
    def root
      Pathname.new(__FILE__).dirname.parent
    end

    # Setting up the environment before running the app...
    def init(config = {})
      # Sort out config file
      @config_file = config.delete(:config_file) || '~/.genevalidatorapp.conf'
      @config_file = Pathname.new(config_file).expand_path
      assert_file_present('config file', config_file, EXIT_CONFIG_FILE_NOT_FOUND)

      @config = {
        num_threads: 1,
        port: 4567,
        host: 'localhost',
        web_dir: Dir.pwd
      }.update(parse_config_file.merge(config))

      assert_genevalidator_installed_and_compatible

      assert_bin_dir('BLAST bin dir', @config[:blast_bin]) if @config[:blast_bin]
      assert_blast_installed_and_compatible

      assert_bin_dir('Mafft bin dir', @config[:mafft_bin]) if @config[:mafft_bin]
      assert_mafft_installed

      assert_blast_database_dir_argument_present
      assert_blast_databases_present_in_database_dir

      Database.scan_databases_dir
      # TODO: Warn if chosen default db does not exist (use the first db instead)

      assert_num_threads_valid
      assert_max_characters_valid if @config[:max_characters]

      require_extension if @config[:require]

      set_up_gv_tempdir
      set_up_public_folder

      # We don't validate port and host settings. If GeneValidator is run
      # self-hosted, bind will fail on incorrect values. If GeneValidator
      # is run via Apache+Passenger, we don't need to worry.

      self
    end

    # Starting the app manually using Thin
    def run
      url = "http://#{config[:host]}:#{config[:port]}"
      server = Thin::Server.new(config[:host], config[:port], signals: false) do
        use Rack::CommonLogger
        run GeneValidatorApp
      end
      server.silent = true
      server.backend.start do
        puts '** GeneValidatorApp is ready.'
        puts "   Go to #{url} in your browser and start analysing Genes!"
        puts '   Press CTRL+C to quit.'
        [:INT, :TERM].each do |sig|
          trap sig do
            server.stop!
            puts
            puts
            puts '** Thank you for using GeneValidatorApp :).'
            puts '   Please cite: '
            puts '             Dragan M., Moghul M.I., Priyam A., Wurm Y (in prep).'
            puts '             GeneValidator: identify problematic gene predictions.'
          end
        end
      end
    rescue
      puts '** Oops! There was an error.'
      puts "   Is GeneValidatorApp already accessible at #{url}?"
      puts '   Try running GeneValidatorApp on another port, like so: genevalidatorapp -p 4570.'
    end

    # Set the max characters accepted from the app (for the app templates)
    def max_characters
      (config[:max_characters]) ? config[:max_characters] : 'undefined'
    end

    # Returns the version of the GeneValidator installed
    def current_gv_version
      `genevalidator --version`
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

    # Run by the logger method - sets the logger level to verbose if in
    #   development environment
    def verbose?
      @verbose ||= (environment == 'development')
    end

    private

    # Copy the public folder (in the app root) to the web_dir location - this
    #   web_dir is then used by the app to serve all dependencies...
    def set_up_public_folder
      @public_dir = Pathname.new(config[:web_dir]) +
                    "GeneValidator_#{Time.now.strftime('%Y%m%d-%H%M%S')}"
      root_public_dir = GeneValidatorApp.root + 'public'
      FileUtils.cp_r(root_public_dir, @public_dir)
    end

    # Creates a Temp directory (starting with 'GeneValidator_') each time
    #   GVapp is started. Within this Temp folder, sub directories are created
    #   in which GeneValidator is run.
    def set_up_gv_tempdir
      @tempdir = Pathname.new(Dir.mktmpdir('GeneValidator_'))
    end

    # Parses the config file.
    def parse_config_file
      logger.debug("Reading configuration file: #{@config_file}.")
      config = YAML.load_file(config_file) || {}
      config.inject({}) { |c, e| c[e.first.to_sym] = e.last; c }
    rescue ArgumentError => error
      puts "*** Error in config file: #{error}."
      puts '    YAML is white space sensitive. Is your config file properly indented?'
      exit 1
    end

    # Write to the config file.
    def write_config_file
      File.open(GeneValidatorApp.config_file, 'w') do |f|
        f.puts(config.delete_if { |_k, v| v.nil? }.to_yaml)
      end
    end

    # Assert whether bin is in $PATH, if not, export to $PATH
    def assert_bin_dir(desc, bin_dir)
      bin_dir = Pathname.new(bin_dir).expand_path
      assert_dir_present(desc, bin_dir)
      export_bin_dir(bin_dir)
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

    #  Assert whether a file (or dir) is present - if not, then exit with the
    #   supplied exit code.
    def assert_file_present(desc, file, exit_code = 1)
      unless file and File.exist?(File.expand_path(file))
        puts "*** Couldn't find #{desc}: #{file}."
        exit exit_code
      end
    end

    alias_method :assert_dir_present, :assert_file_present

    # Assert whether BLAST is installed and compatible.
    def assert_blast_installed_and_compatible
      unless command? 'blastdbcmd'
        puts '*** Could not find BLAST+ binaries.'
        exit EXIT_BLAST_NOT_INSTALLED
      end
      version = `blastdbcmd -version`.split[1]
      unless version >= MINIMUM_BLAST_VERSION
        puts "*** Your BLAST+ version #{version} is outdated."
        puts '    GeneValidatorApp needs NCBI BLAST+ version' \
             " #{MINIMUM_BLAST_VERSION} or higher."
        exit EXIT_BLAST_NOT_COMPATIBLE
      end
    end

    def assert_blast_database_dir_argument_present
      unless @config[:database_dir]
        puts '*** No BLAST dbs have been passed to GeneValidatorApp.'
        puts '    Please use the "-d" command line argument to set the directory'
        puts '    containing the BLAST databases (alternatively set the database_dir'
        puts '    variable in the config file)'
        exit 1
      end
    end

    # Assert whether there are any databases present in the provided database
    #   directory
    def assert_blast_databases_present_in_database_dir
      @config[:database_dir] = File.expand_path(@config[:database_dir])
      database_dir = config[:database_dir]
      out = `blastdbcmd -recursive -list #{database_dir}`
      if out.empty?
        puts "*** Could not find BLAST databases in '#{database_dir}'."
        exit EXIT_NO_BLAST_DATABASE
      elsif out.match(/BLAST Database error/) or not $?.success?
        puts '*** Error obtaining BLAST databases.'
        puts "    Tried: #{find_dbs_command}"
        puts '    Error:'
        out.strip.split("\n").each do |l|
          puts "      #{l}"
        end
        puts "    Please could you report this to 'https://github.com/IsmailM/GeneValidatorApp'?"
        exit EXIT_BLAST_DATABASE_ERROR
      end
    end

    # Asserts whether mafft is installed.
    def assert_mafft_installed
      unless command? 'mafft'
        puts '*** Could not find Mafft binaries.'
        exit EXIT_MAFFT_NOT_INSTALLED
      end
    end

    # Assert whether the num_threads value is valid...
    def assert_num_threads_valid
      @config[:num_threads] = Integer(@config[:num_threads])
      unless @config[:num_threads] > 0
        puts "*** Can't use #{@config[:num_threads]} number of threads."
        puts '    Number of threads should be greater than or equal to 1.'
        exit 1
      end
      if @config[:num_threads] > 256
        logger.warn "*** Number of threads set at #{@config[:num_threads]} is unusually high."
      end
      logger.debug("Will use #{@config[:num_threads]} threads to run GeneValidator.")
    rescue
      puts '*** Number of threads should be a number.'
      exit 1
    end

    # Assert whether the Max Characters value is a number
    def assert_max_characters_valid
      @config[:max_characters] = Integer(@config[:max_characters])
    rescue
      puts "*** The 'Max Characters' value should be a number."
      exit 1
    end

    # Assert whether GV is installed and is also compatible
    def assert_genevalidator_installed_and_compatible
      unless command? 'genevalidator'
        puts '*** GeneValidator is not installed.'
        exit EXIT_GV_NOT_INSTALLED
      end
      version = GeneValidatorApp.current_gv_version
      unless version >= MINIMUM_GV_VERSION
        puts "*** Your GeneValidator (version #{version}) is outdated."
        puts '    GeneValidatorApp requires GeneValidator version' \
             " #{MINIMUM_GV_VERSION} or higher."
        exit EXIT_GV_NOT_COMPATIBLE
      end
    end

    def require_extension
      @config[:require] = Pathname.new(@config[:require]).expand_path
      assert_file_present('extension file', @config[:require])
      require @config[:require]
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
      enable :dump_errors

      # We don't want Sinatra do setup any loggers for us. We will use our own.
      set :logging, nil

      # This is the app root...
      set :root,          lambda { GeneValidatorApp.root }

      # This is the full path to the public folder...
      set :public_folder, lambda { GeneValidatorApp.public_dir }
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

    post '/' do
      cross_origin # Required for the API to work...
      GeneValidator.init(request.url, params)
      GeneValidator.run
    end

    # This error block will only ever be hit if the user gives us a funny
    # sequence or incorrect advanced parameter. Well, we could hit this block
    # if someone is playing around with our HTTP API too.
    error GeneValidator::ArgumentError do
      status 400
      slim :"500", layout: false
    end

    # This will catch any unhandled error and some very special errors. Ideally
    # we will never hit this block. If we do, there's a bug in GeneValidatorApp
    # or something really weird going on.
    # TODO: If we hit this error block we show the stacktrace to the user
    # requesting them to post the same to our Google Group.
    error Exception, GeneValidator::RuntimeError do
      status 500 # TODO Create another template...
      slim :"500", layout: false
    end

    not_found do
      status 404
      slim :"500" # TODO: Create another Template
    end
  end
end
