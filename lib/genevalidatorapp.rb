require 'genevalidatorapp/database'
require 'genevalidatorapp/genevalidator'
require 'genevalidatorapp/logger'
require 'genevalidatorapp/config'
require 'genevalidatorapp/version'
require 'genevalidatorapp/server'
require 'genevalidatorapp/routes'
require 'pathname'
require 'yaml'

module GeneValidatorApp
  # Use a fixed minimum version of BLAST+
  MINIMUM_BLAST_VERSION = '2.2.30+'

  class << self
    attr_reader :public_dir, :tempdir, :config

    def environment
      ENV['RACK_ENV']
    end

    def verbose?
      @verbose ||= (environment == 'development')
    end

    def logger
      @logger ||= Logger.new(STDERR, verbose?)
    end

    def root
      Pathname.new(__FILE__).dirname.parent
    end

    # Set the max characters accepted from the app (for the app templates)
    def max_characters
      (config[:max_characters]) ? config[:max_characters] : 'undefined'
    end

    # Setting up the environment before running the app...
    def init(config = {})
      @config = Config.new(config)
      init_blast_and_mafft_binaries
      init_database
      load_extension
      check_num_threads
      check_max_characters
      init_gv_tempdir
      init_public_dir
      self
    end

    # Starting the app manually using Thin
    def run
      check_host
      Server.run(self)
    rescue Errno::EADDRINUSE
      puts "** Could not bind to port #{config[:port]}."
      puts "   Is GeneValidator already accessible at #{server_url}?"
      puts '   No? Try running GeneValidator on another port, like so:'
      puts
      puts '       genevalidator -p 4570.'
    rescue Errno::EACCES
      puts "** Need root privilege to bind to port #{config[:port]}."
      puts '   It is not advisable to run GeneValidator as root.'
      puts '   Please use Apache/Nginx to bind to a privileged port.'
    end

    def on_start
      puts '** GeneValidator is ready.'
      puts "   Go to #{server_url} in your browser and start analysing genes!"
      puts '   Press CTRL+C to quit.'
      open_in_browser(server_url)
    end

    def on_stop
      puts
      puts '** Thank you for using GeneValidatorApp :).'
      puts '   Please cite: '
      puts '        Dragan M., Moghul M.I., Priyam A., Wurm Y (in prep).'
      puts '        GeneValidator: identify problematic gene predictions.'
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
      Routes.call(env)
    end

    private

    def init_blast_and_mafft_binaries
      init_binaries(config[:blast_bin], 'NCBI BLAST+')
      assert_blast_installed_and_compatible
      init_binaries(config[:mafft_bin], 'Mafft')
      assert_mafft_installed
    end

    def init_binaries(bin_dir, type)
      if bin_dir
        bin_dir = File.expand_path bin_dir
        unless File.exist?(bin_dir) && File.directory?(bin_dir)
          fail BIN_DIR_NOT_FOUND, bin_dir
        end
        logger.debug("Will use #{type} at: #{bin_dir}")
        export_bin_dir bin_dir
      else
        logger.debug("Will use #{type} at: $PATH")
      end
    end

    # Export bin dir to PATH environment variable.
    def export_bin_dir(bin_dir)
      return unless bin_dir
      return if ENV['PATH'].split(':').include? bin_dir
      ENV['PATH'] = "#{bin_dir}:#{ENV['PATH']}"
    end

    def assert_blast_installed_and_compatible
      fail BLAST_NOT_INSTALLED unless command? 'blastdbcmd'
      version = `blastdbcmd -version`.split[1]
      fail BLAST_NOT_COMPATIBLE, version unless version >= MINIMUM_BLAST_VERSION
    end

    def assert_mafft_installed
      fail MAFFT_NOT_INSTALLED unless command? 'mafft'
    end

    def init_database
      fail DATABASE_DIR_NOT_SET unless config[:database_dir]

      config[:database_dir] = File.expand_path(config[:database_dir])
      unless File.exist?(config[:database_dir]) &&
             File.directory?(config[:database_dir])
        fail DATABASE_DIR_NOT_FOUND, config[:database_dir]
      end

      assert_blast_databases_present_in_database_dir
      logger.debug("Will use BLAST+ databases at: #{config[:database_dir]}")

      Database.scan_databases_dir
      Database.each do |database|
        logger.debug("Found #{database.type.chomp} database" \
                     " '#{database.title.chomp}' at '#{database.name.chomp}'")
      end
    end

    def assert_blast_databases_present_in_database_dir
      cmd = "blastdbcmd -recursive -list #{config[:database_dir]}"
      out = `#{cmd}`
      errpat = /BLAST Database error/
      fail NO_BLAST_DATABASE_FOUND, config[:database_dir] if out.empty?
      fail BLAST_DATABASE_ERROR, cmd, out if out.match(errpat) ||
                                             !$?.success?
    end

    def check_num_threads
      num_threads = Integer(config[:num_threads])
      fail NUM_THREADS_INCORRECT unless num_threads > 0
      logger.debug "Will use #{num_threads} threads to run BLAST."
      if num_threads > 256
        logger.warn "Number of threads set at #{num_threads} is unusually high."
      end
    rescue
      raise NUM_THREADS_INCORRECT
    end

    def check_max_characters
      Integer(config[:max_characters]) if config[:max_characters]
    rescue
      raise MAX_CHARACTERS_INCORRECT
    end

    def load_extension
      return unless config[:require]

      config[:require] = File.expand_path config[:require]
      unless File.exist?(config[:require]) && File.file?(config[:require])
        fail EXTENSION_FILE_NOT_FOUND, config[:require]
      end

      logger.debug("Loading extension: #{config[:require]}")
      require config[:require]
    end

    # Creates a Temp directory (starting with 'GeneValidator_') each time
    #   GVapp is started. Within this Temp folder, sub directories are created
    #   in which GeneValidator is run.
    def init_gv_tempdir
      @tempdir = Pathname.new(Dir.mktmpdir('GeneValidator_'))
    end

    # Copy the public folder (in the app root) to the web_dir location - this
    #   web_dir is then used by the app to serve all dependencies...
    def init_public_dir
      @public_dir = Pathname.new(config[:web_dir]) +
                    "GeneValidator_#{Time.now.strftime('%Y%m%d-%H%M%S')}"
      root_public_dir = GeneValidatorApp.root + 'public'
      FileUtils.cp_r(root_public_dir, @public_dir)
    end

    # Check and warn user if host is 0.0.0.0 (default).
    def check_host
      if config[:host] == '0.0.0.0'
        logger.warn 'Will listen on all interfaces (0.0.0.0).' \
                    ' Consider using 127.0.0.1 (--host option).'
      end
    end

    def server_url
      host = config[:host]
      host = 'localhost' if host == '127.0.0.1' || host == '0.0.0.0'
      "http://#{host}:#{config[:port]}"
    end

    def open_in_browser(server_url)
      return if using_ssh? || verbose?
      if RUBY_PLATFORM =~ /linux/ && xdg?
        `xdg-open #{server_url}`
      elsif RUBY_PLATFORM =~ /darwin/
        `open #{server_url}`
      end
    end

    def using_ssh?
      true if ENV['SSH_CLIENT'] || ENV['SSH_TTY'] || ENV['SSH_CONNECTION']
    end

    def xdg?
      true if ENV['DISPLAY'] && command?('xdg-open')
    end

    # Return `true` if the given command exists and is executable.
    def command?(command)
      system("which #{command} > /dev/null 2>&1")
    end
  end
end
