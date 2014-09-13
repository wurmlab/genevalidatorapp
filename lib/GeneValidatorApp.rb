require 'GeneValidatorApp/version'
require 'GeneValidatorApp/PreRunValidation.rb'
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
    full_html.scan(/<div id="report">.*<\/script>/m) do |table|
      # tYW instead modify GeneValidator.
      return table.gsub(/input_file.fa_/, plots_dir)
    end
  end
end
