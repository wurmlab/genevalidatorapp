require 'forwardable'
require 'bio'

module GeneValidatorApp

  class GeneValidator

    class << self
      extend Forwardable

      def_delegators GeneValidatorApp, :config, :logger

      attr_reader :gv_dir, :tmp_gv_dir, :input_file, :xml_file, :raw_seq,
                  :unique_id

      ##
      # Creates the Unique run ID
      # 
      def init(url)
        @unique_id  = create_unique_id
        @tmp_gv_dir = GeneValidatorApp.tempdir + unique_id
        # Create another Unique Id, if it already exists...
        ensure_unique_id if File.exist?(@tmp_gv_dir)
        @gv_dir = GeneValidatorApp.public_dir + 'GeneValidator' + @unique_id
        # Create the Tmp Dir and the create a soft link to it...
        FileUtils.mkdir_p @tmp_gv_dir
        FileUtils.ln_s "#{@tmp_gv_dir}", "#{@gv_dir}"

        # Set up some global variables
        @input_fasta_file = @tmp_gv_dir + 'input_file.fa'
        @xml_file         = @tmp_gv_dir + 'output.xml'
        @raw_seq          = @tmp_gv_dir + 'output.xml.raw_seq'
        @url              = produce_result_url_link(url)
      end

      def run(params)
        write_seq_to_file(params[:seq].to_fasta)
        run_blast(params[:database], params[:seq])
        run_get_raw_sequence(params[:database])
        run_genevalidator
        if params[:result_link]
          @url
        else
          produce_table_html
        end
      end

      private

      def create_unique_id
        logger.debug('Creating Unique ID')
        Time.new.strftime('%Y-%m-%d_%H-%M-%S_%L-%N')
      end

      def ensure_unique_id
        logger.debug('Unique ID already exists - Creating new Unique ID')
        while File.exist?(@tmp_gv_dir)
          @unique_id = GeneValidator.create_unique_id
          @tmp_gv_dir = GeneValidatorApp.tempdir + @unique_id
        end
      end

      def write_seq_to_file(seqs)
        file = File.open(@input_fasta_file, "w+")
        Bio::FlatFile.foreach(StringIO.new(seqs)) do |entry|
          file.write(">#{entry.definition}")
          file.write("\n#{entry.seq.gsub(/\W/, '')}\n")
        end
      rescue IOError => e
        #some error occur, dir not writable etc.
      ensure
        file.close unless file == nil
      end

      # Returns 'blastp' if sequence contains amino acids or returns 'blastx'
      #   if it contains nucleic acids.
      def get_blast_type(sequences)
        (sequences.sequence_type? == Bio::Sequence::AA) ? 'blastp' : 'blastx'
      end

      def run_blast(db, sequence)
        blast_type = get_blast_type(sequence)
        blast = "time #{blast_type} -db #{db} -evalue 1e-5 -outfmt 5" \
                " -max_target_seqs 200 -gapopen 11 -gapextend 1 -query" \
                " #{@input_fasta_file} -out #{@xml_file} -num_threads" \
                " #{config[:num_threads]}"
        exit = %x(#{blast})
        unless $?.exitstatus == 0
          fail IOError, "BLAST exited with the command code: #{$?.exitstatus}."
        end
      end

      def run_get_raw_sequence(db)
        raw_seqs = "time get_raw_sequences -d #{db} -o #{@raw_seq} #{@xml_file}"
        exit = %x(#{raw_seqs})
        unless $?.exitstatus == 0
          fail IOError, "The GeneValidator command failed (get_raw_sequences" \
                        "  exited with exit code: #{$?.exitstatus})."
        end
      end

      def run_genevalidator
        gv_options = "-x #{@xml_file} -r #{@raw_seq} -n #{config[:num_threads]}"
        gv_options += " -m #{config[:mafft_bin]}" if config[:mafft_bin] != nil
        gv_options += " -b #{config[:blast_bin]}" if config[:blast_bin] != nil
        gv_command = "time genevalidator #{gv_options} #{@input_fasta_file}"
        exit = system(gv_command)
        unless exit
          fail IOError, "The Genevalidator command failed (genevalidator" \
                        " exited with the exit code: #{exit}) "
        end
      end

      def produce_table_html
        table_file      = @gv_dir + 'input_file.fa.html/files/table.html'
        orig_plots_dir  = 'files/json/input_file.fa_'
        local_plots_dir = Pathname.new('GeneValidator') + @unique_id +
                          'input_file.fa.html/files/json/input_file.fa_'
        full_html = IO.binread(table_file)
        full_html.gsub(/#{orig_plots_dir}/, local_plots_dir.to_s).gsub(
                  '#Place_external_results_link_here', @url)
      end

      def produce_result_url_link(url)
        url.gsub(/input/, '').gsub(/\/*$/, '') +
        "/GeneValidator/#{@unique_id}/input_file.fa.html/results.html"
      end
    end
  end
end

class String
  extend Forwardable
  
  def_delegators GeneValidatorApp, :logger
  
  # Adds a ID (based on the time when submitted) to sequences that are not in
  #  fasta format.
  def to_fasta
    logger.debug('Adding an ID to sequences that are not in fasta format.')
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

  # Guesses the type of data based on the first sequence - (The app has
  #   a javascript method that ensures that the all input sequences are
  #   of the same method). This method is run from 'get_blast_type'
  def sequence_type?
    Bio::Sequence.new(Bio::FastaFormat.new(self).seq).guess(0.9)
  end
end
