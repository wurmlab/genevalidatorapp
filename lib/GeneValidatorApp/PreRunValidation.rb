require 'logger'
require 'fileutils'
require 'yaml'

LOG = Logger.new(STDOUT)
LOG.formatter = proc do |severity, datetime, _progname, msg|
  "[#{datetime.strftime('%Y-%m-%d %H:%M:%S')}] #{severity}  #{msg}\n"
end

module GeneValidatorApp
  class Prerun
    # This method runs all the validations and returns a hash ('dbs') of all
    #   required information.
    # A dbs hash is created (so that all be returned from a single method).
    #   This dbs hash of hashes contains the following hashes, which
    #   are created so that they can easily be used in the slim template.
    #   => dbs[:dbs]: A hash of all BLAST dbs found within the db root dir
    #   => dbs[:default_db]: A hash of only the default db
    #   => dbs[:rest_dbs]: A hash of the rest of the dbs.
    def self.validate(debug, config_file, tempdir, root, mafft_path,
                      blast_path, web_dir)
      LOG.level = (debug) ? Logger::DEBUG : Logger::INFO
      LOG.info { 'Set up and running pre-run tests.' }
      LOG.debug { 'Initalised debugging mode.' }
      assert_config_file_exists(config_file, root)
      config           = load_config(config_file, root)
      dbs              = {}
      dbs[:dbs]        = scan_blast_database_directory(config['database-dir'])
      dbs[:default_db] = defaultdb(dbs[:dbs], config['default-database'],
                                   config['database-dir'])
      dbs[:rest_dbs]   = dbs[:dbs].clone
      dbs[:rest_dbs].delete(dbs[:default_db].keys[0])
      set_up_public_dir(web_dir, root)
      check_genevalidator_works(root, tempdir, dbs[:default_db].keys[0],
                                mafft_path, blast_path)
      dbs
    end

    # Ensures that the config file exists in either the home directory or the
    #   location that the user specifies as the program argument. The method
    #   outputs a command that the user could use to copy the program over
    #   to their home directory.
    def self.assert_config_file_exists(config_file, root)
      LOG.debug { 'Checking if the config file exists' }
      unless File.exist?(config_file)
        LOG.debug { "No config file found at #{config_file}" }
        puts # a blank line
        puts "Error: The config file cannot be found at #{config_file}"
        puts 'Please refer to the installation guide at: https://github.com/' \
             'IsmailM/GeneValidatorApp'
        puts # a blank line
        puts 'Alternatively, you can copy an examplar config file into your' \
             ' home directory:'
        puts # a blank line
        puts "$ cp #{root + 'examplar_genevalidatorapp.conf'} ~/.genevalidatorapp.conf"
        puts # a blank line
        puts "And then edit your config file"
        puts # a blank line
        puts "$ nano ~/.genevalidatorapp.conf"
        puts # a blank line
        exit
      end
    end

    # This method loads that config file and ensures that the script can access
    #   the necessary variables.
    def self.load_config(config_file, root)
      config = YAML.load_file(config_file)
      unless config['database-dir']
        LOG.debug { "Unable to read config file found at #{config_file}" }
        puts # a blank line
        puts "Error: The config file could not be read at #{config_file}"
        puts # a blank line
        puts '  Please ensure that the config file exists and is properly'
        puts '  formatted.'
        puts # a blank line
        puts '  Alternatively, you can copy an examplar config file into your' \
             '  home directory:'
        puts # a blank line
        puts "$ cp #{root + 'examplar_genevalidatorapp.conf'} ~/.genevalidatorapp.conf"
        puts # a blank line
        puts "And then edit your config file"
        puts # a blank line
        puts "$ nano ~/.genevalidatorapp.conf"
        puts # a blank line
        exit
      end
      config
    end

    ### Obtain a array of dbs (Adapted from SequenceServer)
    # Scan the given directory (including subdirectory) for blast databases.
    # ---
    # Arguments:
    # * db_root(String) - absolute path to the blast databases
    # ---
    # Returns:
    # * a hash of sorted blast databases indexed by their id.
    def self.scan_blast_database_directory(db_root)
      unless File.exist?(db_root)
        LOG.info { "The Blast Database Directory (#{db_root}) does not exist." \
                   " Please correct your config file." }
        exit
      end
      LOG.info { "Looking for databases in #{db_root}" }
      find_dbs_command = %(blastdbcmd -recursive -list #{db_root} -list_outfmt "%p %f %t" 2>&1)
      LOG.debug { "Running: #{find_dbs_command}" }

      db_list = %x|#{find_dbs_command}|
      if db_list.empty?
        LOG.debug { "No databases found in #{db_root}" }
        puts "No formatted blast databases found in '#{db_root}'."
        puts "  Please ensure that there are BLAST database in the #{db_root}."
        exit
      elsif db_list.match(/BLAST Database error/)
        LOG.debug { 'There was a BLAST database error' }
        LOG.debug { 'See below for output recieved from BLAST:' }
        LOG.debug { "#{db_list}" }
        puts 'Error parsing one of the BLAST databases.'
        puts '  Mostly likely some of your BLAST databases were created by an '
        puts '  old version of "makeblastdb".'
        puts '  You will have to manually delete problematic BLAST databases '
        puts '  and subsequently use the latest version of BLAST + to create '
        puts '  new ones.'
        exit
      elsif not $?.success?
        puts 'Error obtaining BLAST databases.'
        puts "  Tried: #{find_dbs_command}"
        puts 'Error:'
        db_list.strip.split("\n").each { |l| puts "\t#{l}"}
        puts ' Please could you report this to "....Link..."'
        exit
      end

      db = {}
      db_list.each_line do |line|
        next if line.empty?  # required for BLAST+ 2.2.22
        type, path, *title =  line.split(' ')
        type  = type.downcase
        next unless type == 'protein' # to ensure we only have protein dbs
        path  = path.freeze
        title = title.join(' ').freeze
        # skip past all but alias file of a NCBI multi-part BLAST database
        if multipart_database_name?(path)
          LOG.debug { "Found a multi-part database volume at #{path} - " \
                     "ignoring it." }
          next
        end
        db[path] = [title: title, type: type]
        LOG.info { "Found #{type} database: #{title} at #{path}" }
      end
      db
    end

    # Adapted from SequenceServer)
    def self.multipart_database_name?(db_name)
      !(db_name.match(/.+\/\S+\d{2}$/).nil?)
    end

    # Extracts the values associated with the default database from the
    #   original database and creates a new hash with this info.
    def self.defaultdb(databases, default_database, database_dir)
      default_db = {}
      if default_database == nil
        # Creates a new hash using just the first key, value...
        default_db = Hash[*databases.first]
      else
        if databases.include?(default_database)
          default_db[default_database] = databases[default_database]
        else
          LOG.debug { "The default database, '#{default_database}' (set in the" \
                      " config file) cannot be found in the the database" \
                      " directory, '#{database_dir}'." }
          puts # a blank line
          puts "Error: The default database: '#{default_database}' could not be" \
               " found in the database directory."
          puts 'The default database can only be one of the following:'
          databases.each_key { |db| puts '> ' + db }
          puts # a blank line
          puts 'Ensure that the default-database variable in the config file ' \
               ' is one of the above paths and then try again.'
          exit
        end
      end
      default_db
    end

    # Create the public dir in the home directory...
    def self.set_up_public_dir(web_dir, root)
      public_dir = root + 'public'
      FileUtils.cp_r(public_dir, web_dir)
    end

    ### Runs GeneValidator with a small test case... If GeneValidator exits
    #   with the right exit code, it is assumed that it works perfectly (this
    #   ensures that mafft and all genevalidator dependencies are installed and
    #   working. This also tests whether the Tempdir is writable.
    def self.check_genevalidator_works(root, tempdir, default_db, mafft_path, blast_path)
      LOG.info { 'Testing if Genevalidator (and it\'s dependencies) are' \
                 ' working.' }
      test_dir  = tempdir + 'initial_tests'
      test_file = root + 'public/GeneValidator/initial_tests/initial_test.fa'

      assert_gv_installed
      assert_gv_version_compatible

      FileUtils.mkdir_p(test_dir)
      FileUtils.cp(test_file, test_dir)
      LOG.debug { "Created test directory at #{test_dir}" }

      options = "-d #{default_db}"
      if mafft_path != nil
        options += " -m #{mafft_path}"
      end
      if blast_path != nil
        options += " -b #{blast_path}"
      end

      cmd = "genevalidator #{options} #{test_dir + 'initial_test.fa'}"

      LOG.debug { "Running: #{cmd}" }
      %x(#{cmd})
      LOG.debug { "GeneValidator exited with exit status: #{$?.exitstatus}" }
      unless $?.exitstatus == 0
        puts # a blank line
        puts 'Error: The Genevalidator unit test failed. This means that your '
        puts '  GeneValidator is not working as expected.'
        puts '  Please ensure that your version of GeneValidator is working'
        puts '  and then try again.'
        puts # a blank line
        exit
      end
      LOG.info { 'All pre-run tests have passed.' }
      puts # a blank line
    end

    ### Ensures that GV is installed and is of the correct version (Adapted
    #     from SequenceServer)...
    def self.assert_gv_installed
      cmd = "GeneValidator"
      LOG.debug { "Running #{cmd}" }
      unless command?(cmd)
        puts 'Error: Could not find GeneValidator. Please confirm that'
        puts '  GeneValidator installed is installed and try again.'
        puts '  Please refer to ...Link... for more information.'
        exit
      end
    end

    # Runs Genevalidator with the '--version' argument to obtain the current
    #   GeneValidator version and then returns this version number.
    def self.current_gv_version
      LOG.debug { "Running: 'genevalidator --version'" }
      version = %x(genevalidator --version)
      version
    end

    # Ensure that the version of GeneValidator installed is compatible with the
    #   current version of the App.
    def self.assert_gv_version_compatible
      version = current_gv_version
      unless version.to_f >= 0.1
        puts "Error: Your GeneValidator (version #{version}) is outdated."
        puts '  This App require GeneValidator version 0.1 or higher.'
        exit
      end
    end

    # check if the given command exists and is executable
    # returns True if all is good. Adapted from SequenceServer
    def self.command?(command)
      %x(which #{command})
      status = ($?.exitstatus == 0) ? true : false
      return status
    end
  end
end
