require 'GeneValidatorApp/version'
require 'bio'
require 'pathname'

# A helper module for the GVApp
module GeneValidatorAppHelper
  # Creates a Unique name using the time (in nanoseconds) + the IP address
  def create_unique_name
    LOG.info { 'Creating the Unique Name' }
    unique_name = Time.new.strftime('%Y-%m-%d_%H-%M-%S-%L-%N') + '_' +
                  request.ip.gsub(/[.:]/, '-')
    return unique_name
  end

  # If the unique name isn't unique, this loop is run until, a unique name is
  #   found.
  def ensure_unique_name(working_dir, tempdir)
    LOG.info { 'Ensuring the run has a unique name' }
    while File.exist?(working_dir)
      unique_name    = create_unique_name
      working_dir = tempdir + unique_name
    end
    return unique_name
  end

  # Adds a ID (based on the time when submitted) to sequences that are not in
  #  fasta format. Adapted from SequenceServer.
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
    if seqs[0] == '>'
      sequences = ''
      data = Bio::FlatFile.open(StringIO.new(seqs))
      data.each_entry do |entry|
        sequences << ">#{entry.definition}"
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
    seq_type = Bio::Sequence.new(sequence.seq).guess(0.9)
    return seq_type
  end

  # Writes the input sequences to a fasta file.
  def create_fasta_file(working_dir, sequences)
    LOG.info { 'Writing the input sequences into a fasta file.' }
    output_file = working_dir + 'input_file.fa'
    File.open(output_file, 'w+') do |f|
      f.write sequences
    end
    unless File.exist?(output_file)
      raise IOError, "The Input Sequences was not written to file"
    end
  end

  # Runs GeneValidator from the command line and return just the table html...
  def run_genevalidator(validations, db, sequences, working_dir, unique_name)
    table_file      = working_dir + "input_file.fa.html/files/table.html"
    local_plots_dir = Pathname.new('Genevalidator') + unique_name +
                      'input_file.fa.html/files/json/input_file.fa_'
    public_json_dir = 'files/json/input_file.fa_'

    type = guess_input_type(sequences)
    blasttype  = 'blastp' if type == Bio::Sequence::AA
    blasttype  = 'blastx' if type == Bio::Sequence::NA

    input_file = working_dir + 'input_file.fa'
    xml_file   = working_dir + 'output.xml'
    raw_seq    = working_dir + 'output.xml.raw_seq'

    blast      = "#{blasttype} -db #{db} -evalue 1e-5 -outfmt 5" \
                 " -max_target_seqs 200 -gapopen 11 -gapextend 1 -query" \
                 " #{input_file} -out #{xml_file}"
    raw_seqs   = "get_raw_sequences -d #{db} -o #{raw_seq} #{xml_file}"
    gv_command = "genevalidator -x #{xml_file} #{input_file} -r #{raw_seq}"

    run_gv(blast, raw_seqs, gv_command)
    unless File.exist?(table_file)
      raise IOError, 'GeneValidator has not created any results files...'
    end
    full_html = IO.binread(table_file)
    return full_html.gsub(/#{public_json_dir}/, local_plots_dir.to_s)
  end

  def run_gv(blast, raw_seqs, gv_command)
    exit  = %x(#{blast})
    unless $?.exitstatus == 0
      raise IOError, "BLAST exited with the command code: #{$?.exitstatus}."
    end

    exit2 = %x(#{raw_seqs})
    unless $?.exitstatus == 0
      raise IOError, "The GeneValidator command failed (get_raw_sequences" \
                     "  exited with exit code: #{$?.exitstatus})."
    end

    exit3 = system(gv_command)
    unless exit3
      raise IOError, "The Genevalidator command failed (genevalidator exited" \
                     " with the eixt code: #{exit3}) "
    end
  end
end
