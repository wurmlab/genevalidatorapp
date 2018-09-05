require 'yaml'
require 'fileutils'

require 'genevalidatorapp/config'
require 'genevalidatorapp/database'
require 'genevalidatorapp/exceptions'
require 'genevalidatorapp/genevalidator'
require 'genevalidatorapp/logger'
require 'genevalidatorapp/routes'
require 'genevalidatorapp/server'
require 'genevalidatorapp/version'

module GeneValidatorApp
  # Use a fixed minimum version of BLAST+
  MINIMUM_BLAST_VERSION = '2.2.30+'.freeze

  class << self
    def environment
      ENV['RACK_ENV']
    end

    def verbose?
      @verbose ||= (environment == 'development')
    end

    def root
      File.dirname(File.dirname(__FILE__))
    end

    def ssl?
      @config[:ssl]
    end

    def logger
      @logger ||= Logger.new(STDERR, verbose?)
    end

    # Setting up the environment before running the app...
    def init(config = {})
      @config = Config.new(config)

      init_binaries
      init_database

      init_dirs

      load_extension
      check_num_threads
      check_max_characters
      self
    end

    attr_reader :config, :temp_dir, :public_dir

    # Starting the app manually
    def run
      check_host
      Server.run(self)
    rescue Errno::EADDRINUSE
      puts "** Could not bind to port #{config[:port]}."
      puts "   Is GeneValidator already accessible at #{server_url}?"
      puts '   No? Try running GeneValidator on another port, like so:'
      puts
      puts '       genevalidator app -p 4570.'
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
      puts '** Thank you for using GeneValidator :).'
      puts '   Please cite: '
      puts '        Dragan M, Moghul MI, Priyam A, Bustos C, Wurm Y. 2016.'
      puts '        GeneValidator: identify problems with protein-coding gene'
      puts '        predictions. Bioinformatics, doi: 10.1093/bioinformatics/btw015.'
    end

    # Rack-interface.
    #
    # Inject our logger in the env and dispatch request to our controller.
    def call(env)
      env['rack.logger'] = logger
      Routes.call(env)
    end

    private

    def init_dirs
      config[:serve_public_dir] = File.expand_path(config[:serve_public_dir])
      unique_start_id = 'GV_' + Time.now.strftime('%Y%m%d-%H-%M-%S').to_s
      @public_dir = File.join(config[:serve_public_dir], unique_start_id)
      init_public_dir
    end

    # Create the Public Dir and copy files from gem root - this public dir
    #   is served by the app is accessible at URL/...
    def init_public_dir
      FileUtils.mkdir_p(File.join(@public_dir, 'GeneValidator'))
      root_web_files = File.join(GeneValidatorApp.root, 'public/web_files')
      root_gv        = File.join(GeneValidatorApp.root, 'public/GeneValidator')
      FileUtils.cp_r(root_web_files, @public_dir)
      FileUtils.cp_r(root_gv, @public_dir)
    end

    def init_binaries
      config[:bin] = init_bins if config[:bin]
      assert_blast_installed_and_compatible
      assert_mafft_installed
    end

    def init_database
      set_database_from_env unless config[:database_dir]
      raise DATABASE_DIR_NOT_SET unless config[:database_dir]

      config[:database_dir] = File.expand_path(config[:database_dir])
      unless File.exist?(config[:database_dir]) &&
             File.directory?(config[:database_dir])
        raise DATABASE_DIR_NOT_FOUND, config[:database_dir]
      end

      assert_blast_databases_present_in_database_dir
      logger.debug("Will use BLAST+ databases at: #{config[:database_dir]}")

      Database.scan_databases_dir
      Database.each do |database|
        logger.debug("Found #{database.type.chomp} database" \
                     " '#{database.title.chomp}' at '#{database.name.chomp}'")
      end
    end

    # attempt to set the database dir to GV_BLAST_DB_DIR if it exists
    def set_database_from_env
      config[:database_dir] = ENV['GV_BLAST_DB_DIR']
    end

    def load_extension
      return unless config[:require]
      config[:require] = File.expand_path config[:require]
      unless File.exist?(config[:require]) && File.file?(config[:require])
        raise EXTENSION_FILE_NOT_FOUND, config[:require]
      end

      logger.debug("Loading extension: #{config[:require]}")
      require config[:require]
    end

    def assert_blast_databases_present_in_database_dir
      cmd = "blastdbcmd -recursive -list '#{config[:database_dir]}'"
      out = `#{cmd}`
      errpat = /BLAST Database error/
      raise NO_BLAST_DATABASE_FOUND, config[:database_dir] if out.empty?
      raise BLAST_DATABASE_ERROR, cmd, out if out.match(errpat) ||
                                              !$CHILD_STATUS.success?
      type = []
      out.lines.each { |l| type << l.split[1] }
      return if type.include? 'Protein'
      raise NO_PROTEIN_BLAST_DATABASE_FOUND, config[:database_dir]
    end

    def check_num_threads
      num_threads = Integer(config[:num_threads])
      raise NUM_THREADS_INCORRECT unless num_threads > 0

      logger.debug "Will use #{num_threads} threads to run BLAST."
      if num_threads > 256
        logger.warn "Number of threads set at #{num_threads} is unusually high."
      end
    rescue StandardError
      raise NUM_THREADS_INCORRECT
    end

    def check_max_characters
      if config[:max_characters] != 'undefined'
        config[:max_characters] = Integer(config[:max_characters])
      end
    rescue StandardError
      raise MAX_CHARACTERS_INCORRECT
    end

    def init_bins
      bins = []
      Array(config[:bin]).each do |bin|
        bins << File.expand_path(bin)
        unless File.exist?(bin) && File.directory?(bin)
          raise BIN_DIR_NOT_FOUND, config[:bin]
        end
        export_bin_dir(bin)
      end
      bins
    end

    ## Checks if dir is in $PATH and if not, it adds the dir to the $PATH.
    def export_bin_dir(bin_dir)
      return unless bin_dir
      return if ENV['PATH'].split(':').include?(bin_dir)
      ENV['PATH'] = "#{bin_dir}:#{ENV['PATH']}"
    end

    def assert_blast_installed_and_compatible
      raise BLAST_NOT_INSTALLED unless command? 'blastdbcmd'
      version = `blastdbcmd -version`.split[1]
      raise BLAST_NOT_COMPATIBLE, version unless version >= MINIMUM_BLAST_VERSION
    end

    def assert_mafft_installed
      raise MAFFT_NOT_INSTALLED unless command? 'mafft'
    end

    # Check and warn user if host is 0.0.0.0 (default).
    def check_host
      return unless config[:host] == '0.0.0.0'
      logger.warn 'Will listen on all interfaces (0.0.0.0).' \
                  ' Consider using 127.0.0.1 (--host option).'
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
