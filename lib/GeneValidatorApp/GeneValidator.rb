require 'forwardable'
require 'bio'
require 'fileutils'

module GeneValidatorApp

  module GeneValidator
    # To signal error in query sequence or options.
    #
    # ArgumentError is raised when BLAST+'s exit status is 1; see [1].
    class ArgumentError < ArgumentError
    end

    # To signal internal errors.
    #
    # RuntimeError is raised when there is a problem in writing the input file,
    # in running BLAST, get_raw_sequence or genevalidator. These are rare,
    # infrastructure errors, used internally, and of concern only to the
    # admins/developers.
    class RuntimeError  < RuntimeError
    end

    class << self
      extend Forwardable

      def_delegators GeneValidatorApp, :config, :logger
      
      attr_reader :gv_dir, :tmp_gv_dir, :input_file, :xml_file, :raw_seq,
                  :unique_id, :params

      #
      def init(url, params)
        create_unique_id
        create_subdir_in_main_tmpdir
        create_soft_link_from_tmpdir_to_GV_dir

        @params = params
        validate_params
        # Set up some global variables
        @url = produce_result_url_link(url)
      end

      def run
        write_seq_to_file
        run_blast
        run_get_raw_sequence
        run_genevalidator
        (@params[:result_link]) ? @url : produce_table_html
      end

      private

      def create_unique_id
        @unique_id = Time.new.strftime('%Y-%m-%d_%H-%M-%S_%L-%N')
        @gv_tmpdir = GeneValidatorApp.tempdir + unique_id
        ensure_unique_id
      end

      def ensure_unique_id
        while File.exist?(@gv_tmpdir)
          @unique_id = GeneValidator.create_unique_id
          @gv_tmpdir = GeneValidatorApp.tempdir + @unique_id
        end
        logger.debug("Unique ID = #{@unique_id}")
      end

      def create_subdir_in_main_tmpdir
        logger.debug("GV Tempdir = #{@gv_tmpdir}")
        FileUtils.mkdir_p(@gv_tmpdir)
      end

      # Create the Tmp Dir and the create a soft link to it...
      def create_soft_link_from_tmpdir_to_GV_dir
        @gv_dir = GeneValidatorApp.public_dir + 'GeneValidator' + @unique_id
        logger.debug("Local GV dir = #{@gv_dir}")
        FileUtils.ln_s "#{@gv_tmpdir}", "#{@gv_dir}"
      end

      def validate_params
        assert_seq_param_present
        assert_validations_param_present
        assert_database_params_present
      end

      def assert_seq_param_present
        unless @params[:seq]
          fail ArgumentError, 'No input sequence provided.'
        end
        logger.debug("seq param = #{@params[:seq]}")
      end

      def assert_validations_param_present
        unless @params[:validations]
          fail ArgumentError, 'No validations specified'
        end
        logger.debug("validations param = #{@params[:validations]}")
      end

      def assert_database_params_present
        unless @params[:database]
          fail ArgumentError, 'No database specified'
        end
        logger.debug("database param = #{@params[:database]}")
      end

      def write_seq_to_file
        @input_fasta_file = @gv_tmpdir + 'input_file.fa'
        seqs = @params[:seq].to_fasta
        logger.debug("Writing input seqs to: '#{@input_fasta_file}'")
        file = File.open(@input_fasta_file, "w+")
        Bio::FlatFile.foreach(StringIO.new(seqs)) do |entry|
          file.write(">#{entry.definition}")
          file.write("\n#{entry.seq.gsub(/\W/, '')}\n")
        end
      rescue IOError => e
        #some error occur, dir not writable etc.
      ensure
        file.close unless file == nil
        assert_input_file_present
      end

      def assert_input_file_present
        unless File.exist?(@input_fasta_file)
          fail RuntimeError, 'GeneValidatorApp was unable to create the input' \
                             ' file.'
        end
      end

      # Returns 'blastp' if sequence contains amino acids or returns 'blastx'
      #   if it contains nucleic acids.
      def get_blast_type(sequences)
        (sequences.sequence_type? == Bio::Sequence::AA) ? 'blastp' : 'blastx'
      end

      def run_blast
        @xml_file  = @gv_tmpdir + 'output.xml'
        blast_type = get_blast_type(@params[:seq])
        blast = "time #{blast_type} -db '#{@params[:database]}' -evalue 1e-5" \
                " -outfmt 5 -max_target_seqs 200 -gapopen 11 -gapextend 1" \
                " -query '#{@input_fasta_file}' -out '#{@xml_file}' -num_threads" \
                " #{config[:num_threads]}"
        logger.debug("Running: #{blast}")
        exit = %x(#{blast})
        logger.debug("BLAST exit status: #{$?.exitstatus}")
        unless $?.exitstatus == 0
          fail RuntimeError, "BLAST exited with the exit code:"\
                             " #{$?.exitstatus}."
        end
      end

      def run_get_raw_sequence
        @raw_seq = @gv_tmpdir + 'output.xml.raw_seq'
        raw_seqs = "time get_raw_sequences -d '#{@params[:database]}' -o" \
                   " '#{@raw_seq}' '#{@xml_file}'"
        logger.debug("Running: #{raw_seqs}")
        exit = %x(#{raw_seqs})
        logger.debug("Get_raw_seqs exit status: #{$?.exitstatus}")
        unless $?.exitstatus == 0
          fail RuntimeError, "The GeneValidator command failed (the" \
                             "get_raw_sequences exited with exit code:"\
                             " #{$?.exitstatus})."
        end
      end

      def run_genevalidator
        gv_cmd = "time genevalidator -x '#{@xml_file}' -r '#{@raw_seq}'" \
                 " -v '#{@params[:validations].to_s.gsub(/[\[\]\"]/, '')}'" \
                 " -n #{config[:num_threads]} #{@input_fasta_file}"

        logger.debug("Running: #{gv_cmd}")
        exit = %x(#{gv_cmd})
        logger.debug("GeneValidator exit status: #{$?.exitstatus}")
        unless $?.exitstatus == 0
          fail RuntimeError, "The Genevalidator command failed (genevalidator" \
                        " exited with the exit code: #{$?.exitstatus}) "
        end
      end

      def produce_table_html
        table_file      = @gv_dir + 'input_file.fa.html/files/table.html'
        orig_plots_dir  = 'files/json/input_file.fa_'
        local_plots_dir = Pathname.new('GeneValidator') + @unique_id +
                          'input_file.fa.html/files/json/input_file.fa_'
        assert_table_output_file_present(table_file)
        full_html = IO.binread(table_file)
        full_html.gsub(/#{orig_plots_dir}/, local_plots_dir.to_s).gsub(
                  '#Place_external_results_link_here', @url)
      end

      def assert_table_output_file_present(table_file)
        unless File.exist?(table_file)
          fail RuntimeError, 'GeneValidator did not produce the required' \
                             ' output file.'
        end
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
