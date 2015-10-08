require 'forwardable'
require 'bio'
require 'fileutils'
require 'genevalidator'
require 'json'

module GeneValidatorApp
  # Module that runs GeneValidator
  module RunGeneValidator
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
    class RuntimeError < RuntimeError
    end

    class << self
      extend Forwardable

      def_delegators GeneValidatorApp, :config, :logger, :public_dir

      attr_reader :gv_dir, :input_file, :xml_file, :raw_seq, :unique_id, :params

      # Setting the scene
      def init(url, params)
        create_unique_id
        create_run_dir
        @params = params
        validate_params
        obtain_db_path
        @json_url = produce_json_url_link(url)
        @url = produce_result_url_link(url)
      end

      # Runs genevalidator & Returns parsed JSON, or link to JSON/results file
      def run
        write_seq_to_file
        run_genevalidator
        copy_json_folder
        { parsed_json: parse_output_json, json_url: @json_url,
          results_url: @url }
      end

      private

      # Creates a unique run ID (based on time),
      def create_unique_id
        @unique_id = Time.new.strftime('%Y-%m-%d_%H-%M-%S_%L-%N')
        @run_dir   = File.join(GeneValidatorApp.public_dir, 'GeneValidator',
                               @unique_id)
        ensure_unique_id
      end

      # Ensures that the Unique id is unique (if a sub dir is present in the
      #  temp dir with the unique id, it simply creates a new one)
      def ensure_unique_id
        while File.exist?(@run_dir)
          @unique_id = create_unique_id
          @run_dir   = File.join(GeneValidatorApp.public_dir, 'GeneValidator',
                                 @unique_id)
        end
        logger.debug("Unique ID = #{@unique_id}")
      end

      # Create a sub_dir in the Tempdir (name is based on unique id)
      def create_run_dir
        logger.debug("GV Tempdir = #{@run_dir}")
        FileUtils.mkdir_p(@run_dir)
      end

      # Validates the paramaters provided via the app.
      #  Only important if POST request is sent via API - Web APP also validates
      #  all params via Javascript.
      def validate_params
        logger.debug("Input Paramaters: #{@params}")
        check_seq_param_present
        check_seq_length
        check_validations_param_present
        check_database_params_present
      end

      # Simply asserts whether that the seq param is present
      def check_seq_param_present
        return if @params[:seq]
        fail ArgumentError, 'No input sequence provided.'
      end

      def check_seq_length
        return unless config[:max_characters] != 'undefined'
        return if @params[:seq].length < config[:max_characters]
        fail ArgumentError, 'The input sequence is too long.'
      end

      # Asserts whether the validations param are specified
      def check_validations_param_present
        return if @params[:validations]
        fail ArgumentError, 'No validations specified'
      end

      # Asserts whether the database parameter is present
      def check_database_params_present
        fail ArgumentError, 'No database specified' unless @params[:database]
      end

      def obtain_db_path
        Database.obtain_original_structure(@params[:database]).each do |db|
          @db = db.name
        end
      end

      # Writes the input sequences to a file with the sub_dir in the temp_dir
      def write_seq_to_file
        @input_file = File.join(@run_dir, 'input_file.fa')
        logger.debug("Writing input seqs to: '#{@input_file}'")
        ensure_unix_line_ending
        ensure_fasta_valid
        File.open(@input_file, 'w+') { |f| f.write(@params[:seq]) }
        assert_input_file_present
      end

      def ensure_unix_line_ending
        @params[:seq].gsub!(/\r\n?/, "\n")
      end

      # Adds a ID (based on the time when submitted) to sequences that are not
      #  in fasta format.
      def ensure_fasta_valid
        logger.debug('Adding an ID to sequences that are not in fasta format.')
        unique_queries = {}
        sequence       = @params[:seq].lstrip
        if sequence[0] != '>'
          sequence.insert(0, '>Submitted:'\
                             "#{Time.now.strftime('%H:%M-%B_%d_%Y')}\n")
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
        @params[:seq] = sequence
      end

      # Asserts that the input file has been generated and is not empty
      def assert_input_file_present
        return if File.exist?(@input_file) && !File.zero?(@input_file)
        fail 'GeneValidatorApp was unable to create the input file.'
      end

      # Returns 'blastp' if sequence contains amino acids or returns 'blastx'
      #   if it contains nucleic acids.
      def get_blast_type(sequences)
        (check_seq_type(sequences) == Bio::Sequence::AA) ? 'blastp' : 'blastx'
      end

      def check_seq_type(sequences)
        Bio::Sequence.new(Bio::FastaFormat.new(sequences).seq).guess(0.9)
      end

      # Runs GeneValidator
      def run_genevalidator
        create_gv_log_file
        run_gv
        assert_json_output_file_produced
      rescue SystemExit
        raise 'GeneValidator failed to run properly'
      end

      def run_gv
        cmd = "genevalidator -v '#{@params[:validations].join(',')}'" \
              " -d #{@db} -n #{config[:num_threads]} #{@input_file}"
        logger.debug("GV command: $ #{cmd}")
        log_file = (logger.debug?) ? '' : "> #{@gv_log_file} 2>&1"
        `#{cmd} #{log_file}`
      end

      def create_gv_log_file
        @gv_log_file = File.join(@run_dir, 'log_file.txt')
        logger.debug("Log file: #{@gv_log_file}")
      end

      # Assets whether the results file is produced by GeneValidator.
      def assert_json_output_file_produced
        @json_file = File.join(@run_dir, 'input_file.fa.json')
        return if File.exist?(@json_file)
        fail 'GeneValidator did not produce the required output file.'
      end

      # Reuturns the URL of the results page.
      def produce_result_url_link(url)
        url.gsub(/input/, '').gsub(%r{/*$}, '') +
          "/GeneValidator/#{@unique_id}/input_file.fa.html/results1.html"
      end

      # Reuturns the URL of the results page.
      def produce_json_url_link(url)
        url.gsub(/input/, '').gsub(%r{/*$}, '') +
          "/GeneValidator/#{@unique_id}/input_file.fa.json"
      end

      def parse_output_json
        json_contents = File.read(output_json_file_path)
        JSON.parse(json_contents)
      end

      def output_json_file_path
        "#{@input_file}.json"
      end

      def copy_json_folder
        json_dir = File.join("#{@input_file}.html", 'files/json', '/.')
        web_dir_json = File.join(public_dir, 'web_files/json')
        logger.debug("Moving JSON files from #{json_dir} to #{web_dir_json}")
        FileUtils.cp_r(json_dir, web_dir_json)
      end
    end
  end
end
