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

      # Setting the scene
      def init(url, params)
        create_unique_id
        create_subdir_in_main_tmpdir
        create_soft_link_from_tmpdir_to_GV_dir
        @params = params
        validate_params
        obtain_db_path
        @url = produce_result_url_link(url)
      end

      # Run BLAST(X/P), get_raw_sequence and genevalidator
      #  Returns html for just the table or a link to the page produced by GV 
      def run
        write_seq_to_file
        run_blast
        run_get_raw_sequence
        run_genevalidator
        (@params[:result_link]) ? @url : produce_table_html
      end

      private

      # Creates a unique run ID (based on time),
      def create_unique_id
        @unique_id = Time.new.strftime('%Y-%m-%d_%H-%M-%S_%L-%N')
        @gv_tmpdir = GeneValidatorApp.tempdir + unique_id
        ensure_unique_id
      end

      # Ensures that the Unique id is unique (if a sub dir is present in the  
      #  temp dir with the unique id, it simply creates a new one)
      def ensure_unique_id
        while File.exist?(@gv_tmpdir)
          @unique_id = GeneValidator.create_unique_id
          @gv_tmpdir = GeneValidatorApp.tempdir + @unique_id
        end
        logger.debug("Unique ID = #{@unique_id}")
      end

      # Create a sub_dir in the Tempdir (name is based on unique id)
      def create_subdir_in_main_tmpdir
        logger.debug("GV Tempdir = #{@gv_tmpdir}")
        FileUtils.mkdir_p(@gv_tmpdir)
      end

      # Create the Tmp Dir and the create a soft link to it.
      def create_soft_link_from_tmpdir_to_GV_dir
        @gv_dir = GeneValidatorApp.public_dir + 'GeneValidator' + @unique_id
        logger.debug("Local GV dir = #{@gv_dir}")
        FileUtils.ln_s "#{@gv_tmpdir}", "#{@gv_dir}"
      end

      # Validates the paramaters provided via the app.
      #  Only important if POST request is sent via API - Web APP, validates 
      #  all params via Javascript.
      def validate_params
        assert_seq_param_present
        # TODO: validate the seq length is smaller than max Characters.
        assert_validations_param_present
        assert_database_params_present
      end

      # Simply asserts whether that the seq param is present
      def assert_seq_param_present
        unless @params[:seq]
          fail ArgumentError, 'No input sequence provided.'
        end
        logger.debug("seq param = #{@params[:seq]}")
      end

      # Asserts whether the validations param are specified
      def assert_validations_param_present
        unless @params[:validations]
          fail ArgumentError, 'No validations specified'
        end
        logger.debug("validations param = #{@params[:validations]}")
      end

      # Asserts whether the database parameter is present
      def assert_database_params_present
        unless @params[:database]
          fail ArgumentError, 'No database specified'
        end
        logger.debug("database param = #{@params[:database]}")
      end

      def obtain_db_path
        Database.obtain_original_structure(@params[:database]).each do |db|
          @db = db.name
        end
      end

      # Writes the input sequences to a file with the sub_dir in the temp_dir
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

      # Asserts whether the input file has been generated and whether it is 
      #  empty
      def assert_input_file_present
        unless File.exist?(@input_fasta_file) || File.zero?(@input_fasta_file)
          fail RuntimeError, 'GeneValidatorApp was unable to create the input' +
                             ' file.'
        end
      end

      # Returns 'blastp' if sequence contains amino acids or returns 'blastx'
      #   if it contains nucleic acids.
      def get_blast_type(sequences)
        (sequences.sequence_type? == Bio::Sequence::AA) ? 'blastp' : 'blastx'
      end

      # Runs BLAST (P/X)
      def run_blast
        @xml_file  = @gv_tmpdir + 'output.xml'
        blast_type = get_blast_type(@params[:seq])
        blast = "time #{blast_type} -db '#{@db}' -evalue 1e-5 -outfmt 5 " +
                " -max_target_seqs 200 -gapopen 11 -gapextend 1" +
                " -query '#{@input_fasta_file}' -out '#{@xml_file}'" +
                " -num_threads #{config[:num_threads]}"
        logger.debug("Running: #{blast}")
        exit = %x(#{blast})
        logger.debug("BLAST exit status: #{$?.exitstatus}")
        assert_exit_code_valid(blast_type.capitalize, $?.exitstatus)
      end

      # Run get_raw_sequence (script from genevalidator)
      def run_get_raw_sequence
        @raw_seq = @gv_tmpdir + 'output.xml.raw_seq'
        raw_seqs = "time get_raw_sequences -d '#{@db}' -o '#{@raw_seq}'" +
                   " '#{@xml_file}'"
        logger.debug("Running: #{raw_seqs}")
        exit = %x(#{raw_seqs})
        logger.debug("Get_raw_seqs exit status: #{$?.exitstatus}")
        assert_exit_code_valid('GeneValidator (get_raw_sequences)',
                               $?.exitstatus)
      end

      # Runs GeneValidator
      def run_genevalidator
        gv_cmd = "time genevalidator -x '#{@xml_file}' -r '#{@raw_seq}'" +
                 " -v '#{@params[:validations].to_s.gsub(/[\[\]\"]/, '')}'" +
                 " -n #{config[:num_threads]} #{@input_fasta_file}"
        logger.debug("Running: #{gv_cmd}")
        exit = %x(#{gv_cmd})
        logger.debug("GeneValidator exit status: #{$?.exitstatus}")
        assert_exit_code_valid('GeneValidator', $?.exitstatus)
        assert_table_output_file_produced
      end

      # Assets whether the exit code is equal to 0, else fails with RuntimeError
      def assert_exit_code_valid(program, exit_code)
        unless exit_code == 0
          fail RuntimeError, "#{program} exited with the exit code:" +
                             " #{exit_code}."
        end
      end

      # Assets whether the results file is produced by GeneValidator. 
      def assert_table_output_file_produced
        @table_file = @gv_dir + 'input_file.fa.html/files/table.html'
        unless File.exist?(@table_file)
          fail RuntimeError, 'GeneValidator did not produce the required' +
                             ' output file.'
        end
      end

      # Reads the GV output table file.
      # Updates links to the plots with relative links to plot jsons. 
      def produce_table_html
        orig_plots_dir  = 'files/json/input_file.fa_'
        local_plots_dir = Pathname.new('GeneValidator') + @unique_id +
                          'input_file.fa.html/files/json/input_file.fa_'
        full_html = IO.binread(@table_file)
        full_html.gsub(/#{orig_plots_dir}/, local_plots_dir.to_s).gsub(
                  '#Place_external_results_link_here', @url)
      end

      # Reuturns the URL of the results page.
      def produce_result_url_link(url)
        url.gsub(/input/, '').gsub(/\/*$/, '') +
        "/GeneValidator/#{@unique_id}/input_file.fa.html/results.html"
      end
    end
  end
end

# Entending the String Class with a few useful functions.
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
