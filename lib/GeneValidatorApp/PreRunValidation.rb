require 'fileutils'
require 'logger'


LOG = Logger.new(STDOUT)
LOG.formatter = proc do |severity, datetime, progname, msg|
  "#{datetime}: #{msg}\n"
end
LOG.level = Logger::INFO



### Runs GeneValidator with a small test case... If GeneValidator exits with the
#   the right exit code, it is assumed that it works perfectly. This also tests
#   the Tempdir is writable....
def check_genevalidator_works(tempdir, default_db)
  initial_tests = File.join(tempdir, 'initial_tests')
  test_file     = File.join("#{File.dirname(__FILE__)}", '..', '..', 'public',
                            'GeneValidator', 'initial_tests', 'initial_test.fa')

  FileUtils.mkdir_p(initial_tests)
  FileUtils.cp(test_file, initial_tests)

  command    = 'Genevalidator -d ' + default_db + ' ' + File.join(initial_tests,
               'initial_test.fa')
  %x(#{command})
  unless $?.exitstatus == 0
    raise IOError, "Genevalidator exited with the command code: #{exit}." \
                   " It is possible that GeneValidator has not properly been " 
                   "installed."
  end
end

##### The below has been adapted from SequenceServer

### Obtain a array of dbs 
# Scan the given directory (including subdirectory) for blast databases.
# ---
# Arguments:
# * db_root(String) - absolute path to the blast databases
# ---
# Returns:
# * a hash of sorted blast databases indexed by their id.
def scan_blast_database_directory(db_root)
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
    type  = type.downcase.intern
    path  = path.freeze
    title = title.join(' ').freeze
    # # skip past all but alias file of a NCBI multi-part BLAST database
    if multipart_database_name?(path)
      puts "Found a multi-part database volume at #{path} - ignoring it."
      # logger.info(%|Found a multi-part database volume at #{path} - ignoring it.|)
      next
    end

    db[title] = [path: path, type:type]

    puts "Found #{type} database: #{title} at #{path}"
    # logger.info("Found #{type} database: #{title} at #{path}")
  end
  db
end

def multipart_database_name?(db_name)
  !(db_name.match(/.+\/\S+\d{2}$/).nil?)
end

### Ensures that GV is installed and is of the correct version...
def assert_gv_installed_and_compatible()
  unless command? 'genevalidator'
    puts "*** Could not find GeneValidator. Please Confirm that you have "
    puts "    GeneValidator installed and try again. "
    puts "    Please refer to ...Link... for more information."
    exit
  end
  ### TODO: Add the --version argument to GeneValidator
  # version = %x|genevalidator -version|.split[1]
  # unless version >= '1.0'
  #   puts "*** Your GeneValidator version #{version} is outdated."
  #   puts "    This App require GeneValidator version 1.0 or higher."
  #   exit
  # end
end

# check if the given command exists and is executable
# returns True if all is good.
def command?(command)
  system("which #{command} > /dev/null 2>&1")
end


def choose_default(databases)
  default_db      = {}
  db_titles = databases.keys
  puts # a blank line
  puts "#{databases.length} databases found."
  db_titles.each_with_index { |db, idx| puts "#{idx + 1}: #{db}" }
  puts # a blank line
  puts "Please choose your default database. (Pick a number between 1 and #{db_titles.length}) "
  print '> '
  inp = $stdin.gets.chomp
  input = inp.to_i
  until (input <= db_titles.length && input >= 1) 
    puts # a blank line
    puts "The input: '#{inp}' is not recognised - please try again."
    puts # a blank line
    db_titles.each_with_index { |db, idx| puts "#{idx + 1}: #{db}" }
    puts # a blank line
    puts "Please choose your default database. (Pick a number between 1 and #{db_titles.length}) "
    print '> '
    inp = $stdin.gets.chomp
  end
  if input <= db_titles.length && input >= 1
    db_number = input - 1
    default_db_name = db_titles[db_number]
  end
  puts "You have chosen #{default_db_name} as your default database."
  puts # a blank line

  #Create a separate HASH for the default database
  default_db[default_db_name] = databases[default_db_name]

  # raise IOError,  if databases.include?(default_db_name)
  return default_db
end

