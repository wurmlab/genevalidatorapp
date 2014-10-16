require 'GeneValidatorApp/version'

# A helper module for the GVApp
module GeneValidatorAppHelper
  # Creates a Unique name using the time (even including nanoseconds) and the
  #  the user's IP address
  def create_unique_name
    unique_name = Time.new.strftime('%Y-%m-%d_%H-%M-%S-%L-%N') + '_' +
                  request.ip.gsub(/[.:]/, '-')
    LOG.debug { "Unique name: #{unique_name}" }
    unique_name
  end

  # If the unique name isn't 'unique', the loop within this method is run until
  #   a unique name is found.
  def ensure_unique_name(working_dir, tempdir)
    LOG.debug { 'Ensuring the run has a unique name' }
    while File.exist?(working_dir)
      unique_name = create_unique_name
      working_dir = tempdir + unique_name
    end
    unique_name
  end

  # Writes the input sequences to a fasta file.
  def clean_sequences(seqs, working_dir)
    LOG.debug { "Converting to clean fasta (no non-letter character)" \
                " and writing to file." }
    seqs = seqs.to_fasta
    output_file = working_dir + 'input_file.fa'
    begin
      file = File.open(output_file, "w+")
      Bio::FlatFile.foreach(StringIO.new(seqs)) do |entry|
        file.write(">#{entry.definition}")
        file.write("\n#{entry.seq.gsub(/\W/, '')}\n")
      end
    rescue IOError => e
      #some error occur, dir not writable etc.
    ensure
      file.close unless file == nil
    end
    unless File.exist?(output_file)
      fail IOError, 'There was an error writing the input sequences to file'
    end
    LOG.debug { "Sequences have been written to: #{output_file}" }
  end

  # Guesses the type of data based on the first sequence - (The app has
  #   a javascript method that ensures that the all input sequences are
  #   of the same method). This method is run from 'run_genevalidator'
  def guess_input_type(sequences)
    sequence = Bio::FastaFormat.new(sequences)
    seq_type = Bio::Sequence.new(sequence.seq).guess(0.9)
    seq_type
  end

  # Runs GeneValidator from the command line and return just the table html.
  #  This method also gsubs the links for the json file (for plots) so that they
  #  with GeneValidator setup.
  def run_genevalidator(validations, db, sequences, working_dir, unique_name, mafft_path, blast_path)
    table_file      = working_dir + 'input_file.fa.html/files/table.html'
    orig_plots_dir  = 'files/json/input_file.fa_'
    local_plots_dir = Pathname.new('Genevalidator') + unique_name +
                      'input_file.fa.html/files/json/input_file.fa_'
    input_file      = working_dir + 'input_file.fa'
    xml_file        = working_dir + 'output.xml'
    raw_seq         = working_dir + 'output.xml.raw_seq'

    type       = guess_input_type(sequences)
    blasttype  = 'blastp' if type == Bio::Sequence::AA
    blasttype  = 'blastx' if type == Bio::Sequence::NA

    blast      = "#{blasttype} -db #{db} -evalue 1e-5 -outfmt 5" \
                 " -max_target_seqs 200 -gapopen 11 -gapextend 1 -query" \
                 " #{input_file} -out #{xml_file}"
    raw_seqs   = "get_raw_sequences -d #{db} -o #{raw_seq} #{xml_file}"

    gv_options = "-x #{xml_file} -r #{raw_seq}"
    if mafft_path != nil
      gv_options += " -m #{mafft_path}"
    end 
    if blast_path != nil
      gv_options += " -b #{blast_path}"
    end
    gv_command = "genevalidator #{gv_options} #{input_file}"

    run_gv(blast, raw_seqs, gv_command)
    unless File.exist?(table_file)
      fail IOError, 'GeneValidator did not produce the requested results.'
    end
    full_html = IO.binread(table_file)
    full_html.gsub(/#{orig_plots_dir}/, local_plots_dir.to_s)
  end

  # Method run from run_genevalidator(). Simply runs BLAST, get_raw_sequences
  #  and genevalidator.
  def run_gv(blast, raw_seqs, gv_command)
    LOG.debug { "Running: #{blast}" }
    exit = %x(#{blast})
    unless $?.exitstatus == 0
      fail IOError, "BLAST exited with the command code: #{$?.exitstatus}."
    end
    LOG.debug { "BLAST exit Status: #{$?.exitstatus}" }

    LOG.debug { "Running: #{raw_seqs}" }
    exit2 = %x(#{raw_seqs})
    unless $?.exitstatus == 0
      fail IOError, "The GeneValidator command failed (get_raw_sequences" \
                     "  exited with exit code: #{$?.exitstatus})."
    end
    LOG.debug { "get_raw_sequences exit Status: #{$?.exitstatus}" }

    LOG.debug { "Running: #{gv_command}" }
    exit3 = system(gv_command)
    unless exit3
      fail IOError, "The Genevalidator command failed (genevalidator exited" \
                     " with the exit code: #{exit3}) "
    end
    LOG.debug { "genevalidator exit Status: #{$?.exitstatus}" }
  end
end

class String
  # Adds a ID (based on the time when submitted) to sequences that are not in
  #  fasta format. Adapted from SequenceServer.
  def to_fasta
    LOG.debug { 'Adding an ID to sequences that are not in fasta format.' }
    unique_queries = {}
    sequence       = self.lstrip
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
    sequence
  end
end
