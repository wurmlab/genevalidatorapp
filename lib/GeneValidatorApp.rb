require 'GeneValidatorApp/version'
require 'fileutils'

# A helper module for the GVApp
module GeneValidatorApp
  # Creates a Unique name using the time (in nanoseconds) + the IP address
  def create_unique_name
    puts 'creating a unique name'
    unique_name = Time.new.strftime('%Y-%m-%d_%H-%M-%S-%L-%N') + '_' +
                  request.ip.gsub('.', '-')
    return unique_name
  end

  # If the unique name isn't unique, this loop is run until, a unique name is
  #   found.
  def ensure_unique_name(working_dir, tempdir)
    puts 'Ensuring the run has a unique name'
    while File.exist?(working_dir)
      unique_name    = create_unique_name
      working_dir = File.join(tempdir, unique_name)
    end
    return unique_name
  end

  # Adds a ID (based on the submission time) to sequences that are not in fasta
  #   format. Adapted from SequenceServer.
  def to_fasta(sequence)
    sequence = sequence.lstrip
    unique_queries = {}
    if sequence[0, 1] != '>'
      sequence.insert(0, ">Submitted:#{Time.now.strftime('%H:%M-%B_%d_%Y')}\n")
    end
    sequence.gsub!(/^\>(\S+)/) do |s|
      if unique_queries.key?(s)
        unique_queries[s] += 1
        s + '_' + (unique_queries[s] - 1).to_s
      else
        unique_queries[s] = 1
        s
      end
    end
    return sequence
  end

  # Writes the input sequences to a fasta file.
  def create_fasta_file(working_dir, sequences)
    puts 'Writing the input sequences into a fasta file.'
    File.open(File.join(working_dir, 'input_file.fa'), 'w+') do |f|
      f.write sequences
    end
  end

  # Runs GeneValidator from the command line and return just the table html...
  def run_genevalidator(validations, db, working_dir, unique_name)
    index_file = File.join(working_dir, 'input_file.fa.html', 'index.html')
    command    = 'Genevalidator -v "' + validations + '" -d "' + db + '" "' +
                  File.join(working_dir, 'input_file.fa') + '"'
    exit       = system(command)
    unless exit
      raise IOError, "Genevalidator exited with the command code: #{exit}."
    end
    unless File.exist?(index_file)
      raise IOError, 'GeneValidator has not created any results files...'
    end
    html_table = extract_table_html(index_file, unique_name)
    return html_table
  end

  # Extracts the HTML table from the output index file. And then edits it
  #   slighly to embeded into the app...
  def extract_table_html(index_file, unique_name)
    plots_dir  = File.join('Genevalidator', unique_name, 'input_file.fa.html',
                           'input_file.fa_')

    full_html = IO.binread(index_file)
    cleanhtml = full_html.gsub(/>\s*</, '><').gsub(/[\t\n]/, '').gsub('  ', ' ')
    cleanhtml.scan(/<div id="report">.*/) do |table|
      # tYW instead modify GeneValidator.
      @table = table.gsub('</div></body></html>', '').gsub(/input_file.fa_/,
                                                          plots_dir)
    end
    results = create_results(@table)
    return results
  end

  # Edits the results so that they are embedded in a nice box
  ### TODO: PUT this into the template with display:none and then use javascript
  def create_results(insides)
    puts 'creating results'
    results = '<div id="results_box"><h2 class="page-header">Results</h2>' +
              insides + '</div>'
    return results
  end
end



#### Perhaps put the below in a new file, in a new module...


### Runs GeneValidator with a small test case... If GeneValidator exits with the 
#   the right exit code, it is assumed that it works perfectly. This also tests
#   the Tempdir is writable.... 
def check_genevalidator_works(temp_dir, db_array)
  #test_unit = File.join(.......)

    # command    = 'Genevalidator -v "' + validations + '" -d ' + db + ' ' +
    #               File.join(working_dir, 'input_file.fa')
    # exit       = system(command)

    # unless exit
    #   puts "*** Genevalidator exited with the command code: #{exit}."
    #   exit
    # end

  
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
      puts "    Mostly likely some of your BLAST databases were created by an old version of 'makeblastdb'."
      puts "    You will have to manually delete problematic BLAST databases and subsequently use the latest version of BLAST + to create new ones."
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
      type, name, *title =  line.split(' ')
      type  = type.downcase.intern
      name  = name.freeze
      title = title.join(' ').freeze
      # # skip past all but alias file of a NCBI multi-part BLAST database
      # if multipart_database_name?(name)
      #   puts "Found a multi-part database volume at #{name} - ignoring it."
      #   # logger.info(%|Found a multi-part database volume at #{name} - ignoring it.|)
      #   next
      # end

      db[title] = [name: name, type:type]

      puts "Found #{type} database: #{title} at #{name}"
      # logger.info("Found #{type} database: #{title} at #{name}")
    end
    puts db
    db
  end



### Ensures that GV is installed and is of the correct version...
def assert_gv_installed_and_compatible()
  unless command? 'genevalidator'
    puts "*** Could not find GeneValidator."
    puts "    Please Confirm that you have GeneValidator installed and try again. "
    puts "    Please refer to ...Link... for more information."
    exit
  end
  ### Add the --version argument to GeneValidator
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
  db_titles = []
  databases.each do |title, hash|
    db_titles.push(title)
  end

  raise IOError, ':( Something went wrong ' if databases.length != db_titles.length

  puts # a blank line
  puts "#{databases.length} databases have found."
  puts # a blank line

  db_number = 0
  while db_number < db_titles.length
    puts "[#{db_number + 1}]:  #{db_titles[db_number]}"
    db_number += 1
  end

  puts # a blank line
  puts "Please choose your default database. (Pick a number between 1 and #{db_titles.length}) "
  print '> '
  inp = $stdin.gets.chomp
  i = inp.to_i - 1
  default_db = db_titles[i]
  puts "You have chosen #{default_db} as your default database."
  puts # a blank line

  
  return default_db
end
