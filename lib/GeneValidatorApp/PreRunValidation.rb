require 'logger'
require 'fileutils'
require 'yaml'
require 'pathname'

LOG = Logger.new(STDOUT)
LOG.formatter = proc do |severity, datetime, progname, msg|
  "#{datetime}: #{msg}\n"
end
LOG.level = Logger::INFO

module GeneValidatorApp
  class Prerun

    def self.validate(config_file, tempdir, root)
      assert_config_file_exists(config_file, root)
      config                = YAML.load_file(config_file)
      dbs                   = {}
      dbs[:dbs]             = scan_blast_database_directory(config['database'])
      dbs[:default_db]      = defaultdb(dbs[:dbs], config['default-database'])
      dbs[:non_default_dbs] = dbs[:dbs].clone
      dbs[:non_default_dbs].delete(config['default-database'])
      check_genevalidator_works(root, tempdir, config['default-database'])
      return dbs
    end

    def self.assert_config_file_exists(config_file, root)
      if File.exist?(config_file) == false
        puts # a blank line
        puts "Error: The config file cannot be found at #{config_file}"
        puts "Please refer to the installation guide at: https://github.com/" \
             "IsmailM/GeneValidatorApp"
        puts # a blank line
        puts "Alternatively, you can copy an examplar config file into your" \
             "home directory:"
        puts # a blank line
        puts "$ cp #{root + '.genevalidatorapp.conf'} ~/.genevalidatorapp.conf"
        puts # a blank line
        exit
      end
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
      find_dbs_command = %|blastdbcmd -recursive -list #{db_root} -list_outfmt "%p %f %t" 2>&1|

      db_list = %x|#{find_dbs_command}|
      if db_list.empty?
        puts "*** No formatted blast databases found in '#{db_root}'."
        puts "    Please ensure that there are BLAST database in the #{db_root}."
        exit
      elsif db_list.match(/BLAST Database error/)
        puts "*** Error parsing one of the BLAST databases."
        puts "    Mostly likely some of your BLAST databases were created by an "
        puts "    old version of 'makeblastdb'."
        puts "    You will have to manually delete problematic BLAST databases "
        puts "    and subsequently use the latest version of BLAST + to create "
        puts "    new ones."
        exit
      elsif not $?.success?
        puts "*** Error obtaining BLAST databases."
        puts "    Tried: #{find_dbs_command}"
        puts "    Error:"
        db_list.strip.split("\n").each { |l| puts "\t#{l}"}
        puts "    Please could you report this to '....Link...'"
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
          LOG.info { "Found a multi-part database volume at #{path} - " \
                     "ignoring it." }
          next
        end
        db[path] = [title: title, type:type]
        LOG.info { "Found #{type} database: #{title} at #{path}" }
      end
      db
    end

    # Adapted from SequenceServer)
    def self.multipart_database_name?(db_name)
      !(db_name.match(/.+\/\S+\d{2}$/).nil?)
    end

    def self.defaultdb(databases, default_database)
      default_db = {}
      if databases.include?(default_database)
        default_db[default_database] = databases[default_database]
      end
      # TODO: If not found, look for the db ensure that the db exists by
      #   checking the path...
      return default_db
    end

    ### Runs GeneValidator with a small test case... If GeneValidator exits
    #   with the right exit code, it is assumed that it works perfectly. This
    #   also tests the Tempdir is writable....
    def self.check_genevalidator_works(root, tempdir, default_db)
      LOG.info { 'Testing if Genevalidator (and all it\'s dependencies) are' \
                 ' working.' }
      test_dir  = tempdir + 'initial_tests'
      test_file = root + 'public/GeneValidator/initial_tests/initial_test.fa'

      assert_gv_installed_and_compatible

      FileUtils.mkdir_p(test_dir)
      FileUtils.cp(test_file, test_dir)
      cmd = "genevalidator -d #{default_db} #{test_dir + 'initial_test.fa'}"
      %x(#{cmd})
      unless $?.exitstatus == 0
        raise IOError, "Genevalidator exited with the command code:" \
                       " #{$?.exitstatus}. It is possible that GeneValidator" \
                       " has not properly been installed."
      end
      LOG.info { 'All pre-run tests have passed.' }
      puts # a blank line
    end

    ### Ensures that GV is installed and is of the correct version (Adapted
    #     from SequenceServer)...
    def self.assert_gv_installed_and_compatible
      unless command?('genevalidator --version')
        puts "*** Could not find GeneValidator. Please confirm that"
        puts "    GeneValidator installed is installed and try again."
        puts "    Please refer to ...Link... for more information."
        exit
      end
      version = %x|genevalidator --version|
      unless version.to_f >= 0.1
        puts "*** Your GeneValidator (version #{version}) is outdated."
        puts "    This App require GeneValidator version 0.1 or higher."
        exit
      end
    end

    # check if the given command exists and is executable
    # returns True if all is good. Adapted from SequenceServer
    def self.command?(command)
      %x|which #{command}|
      return true if $?.exitstatus != 0
    end
  end
end
