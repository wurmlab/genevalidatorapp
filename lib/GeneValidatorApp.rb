require 'GeneValidatorApp/version'
require 'fileutils'
require 'logger'
require 'bio'

# A helper module for the GVApp
module GeneValidatorAppHelper
  # Creates a Unique name using the time (in nanoseconds) + the IP address
  def create_unique_name
    LOG.info { 'Creating the Unique Name' }
    puts 'creating a unique name'
    unique_name = Time.new.strftime('%Y-%m-%d_%H-%M-%S-%L-%N') + '_' +
                  request.ip.gsub('.', '-')
    return unique_name
  end

  # If the unique name isn't unique, this loop is run until, a unique name is
  #   found.
  def ensure_unique_name(working_dir, tempdir)
    LOG.info { 'Ensuring the run has a unique name' }
    while File.exist?(working_dir)
      unique_name    = create_unique_name
      working_dir = File.join(tempdir, unique_name)
    end
    return unique_name
  end

  # Adds a ID (based on the time when submitted) to sequences that are not in fasta
  #   format. Adapted from SequenceServer.
  def to_fasta(sequence)
    sequence = sequence.lstrip
    unique_queries = {}
    if sequence[0] != '>'
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
  def clean_sequences(seqs)
    sequences = ''
    if seqs[0] == '>'
      data = Bio::FlatFile.open(StringIO.new(seqs))
      data.each_entry do |entry|
        sequences << ">#{entry.entry_id}"
        sequences << "\n#{entry.seq.gsub(/\W/, '')}\n"
      end
    else
      sequences = seqs.gsub(/[\d\W]/, '')
    end
    return sequences
  end

  # Guesses the type of data based on the first sequence - (The app has
  #   a javascript method that ensures that the all input sequences are
  #   of the same method.
  def guess_input_type(sequences)
    sequence = Bio::FastaFormat.new(sequences)
    type = Bio::Sequence.new(sequence.seq).guess(0.9)

    if type == Bio::Sequence::NA
      seq_type = 'genetic'
    elsif type == Bio::Sequence::AA
      seq_type = 'protein'
    end
    return seq_type
  end

  # Writes the input sequences to a fasta file.
  def create_fasta_file(working_dir, sequences)
    LOG.info { 'Writing the input sequences into a fasta file.' }
    File.open(File.join(working_dir, 'input_file.fa'), 'w+') do |f|
      f.write sequences
    end
  end

  # Runs GeneValidator from the command line and return just the table html...
  def run_genevalidator(validations, db, type, working_dir, unique_name)
    table_file = File.join(working_dir, 'input_file.fa.html/files/table.html')

    plots_dir  = File.join('Genevalidator', unique_name, 'input_file.fa.html',
                           'files/json/input_file.fa_')
    current_plots_dir = 'files/json/input_file.fa_'

    # Set up Variables
    blasttype  = 'blastp' if type == 'protein'
    blasttype  = 'blastx' if type == 'genetic'
    input_file = File.join(working_dir,'input_file.fa')
    xml_file   = File.join(working_dir, 'output.xml')
    raw_seq    = File.join(working_dir, 'output.xml.raw_seq')

    # command    = 'time Genevalidator -v "' + validations + '" -d "' + db + '" "' +
    #               File.join(working_dir, 'input_file.fa') + '"'
    # exit       = system(command)

    blast_command = ["#{blasttype} -db #{db} ",
                                  "-evalue 1e-5",
                                  " -outfmt 5 -max_target_seqs 200 -gapopen 11 ",
                                  "-gapextend 1 -query #{input_file} -out #{xml_file}" ].join(' ')
    raw_sequences_command = "get_raw_sequences -d #{db} -o #{raw_seq} #{xml_file} "
    genevalidator_command = "genevalidator -x #{xml_file} #{input_file} -r #{raw_seq}"

    exit  = system(blast_command)
    exit2 = system(raw_sequences_command)
    exit3 = system(genevalidator_command)

    unless exit
      raise IOError, "BLAST exited with the command code: #{exit}."
    end
    unless exit2
      # raise IOError, "The GeneValidator command failed (get_raw_sequences exited with exit code: #{exit2})."
      puts "get_raw_sequences command is exiting with exit code: #{exit2}"
    end
    unless exit3
      raise IOError, "The Genevalidator command failed (genevalidator exited with the eixt code: #{exit3}) "
    end
    unless File.exist?(table_file)
      raise IOError, 'GeneValidator has not created any results files...'
    end
    full_html = IO.binread(table_file)
    return full_html.gsub(/#{current_plots_dir}/, plots_dir)
  end
end
