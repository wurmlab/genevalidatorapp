require 'find'
require 'digest/md5'
require 'forwardable'

module GeneValidatorApp

  # Captures a directory containing FASTA files and BLAST databases.
  #
  # It is important that formatted BLAST database files have the same dirname and
  # basename as the source FASTA for GeneValidatorApp to be able to tell formatted
  # FASTA from unformatted. And that FASTA files be formatted with `parse_seqids`
  # option of `makeblastdb` for sequence retrieval to work.
  #
  # GeneValidatorApp will always place BLAST database files alongside input FASTA,
  # and use `parse_seqids` option of `makeblastdb` to format databases.
  class Database < Struct.new(:name, :title, :type)

    class << self

      extend Forwardable

      def_delegators GeneValidatorApp, :config, :logger

      def collection
        @collection ||= {}
      end

      private :collection

      def <<(database)
        collection[database.id] = database
      end

      def [](ids)
        ids = Array ids
        collection.values_at(*ids)
      end

      def ids
        collection.keys
      end

      def all
        collection.values
      end

      def include?(path)
        collection.include? Digest::MD5.hexdigest path
      end

      def group_by(&block)
        all.group_by(&block)
      end

      def first
        all.first
      end

      def default_db
        if config[:default_db] && collection.include?(Digest::MD5.hexdigest config[:default_db])
          all.find { |a| a.name == config[:default_db] }
        else
          all.first
        end
      end

      def non_default_dbs
        all.find_all { |a| a != Database.default_db }
      end

      # Returns the original structure that the title is within. 
      def obtain_original_structure(db_title)
        all.find_all { |a| a.title.chomp == db_title }
      end

      # Recurisvely scan `database_dir` for blast databases.
      def scan_databases_dir
        database_dir = config[:database_dir]
        list = %x|blastdbcmd -recursive -list #{database_dir} -list_outfmt "%p	%f	%t" 2>&1|
        list.each_line do |line|
          type, name, title =  line.split('	')
          next if multipart_database_name?(name)
          next unless type.downcase == 'protein' # to ensure we only have protein dbs
          self << Database.new(name, title, type)
        end
      end

      # Returns true if the database name appears to be a multi-part database name.
      #
      # e.g.
      # /home/ben/pd.ben/sequenceserver/db/nr.00 => yes
      # /home/ben/pd.ben/sequenceserver/db/nr => no
      # /home/ben/pd.ben/sequenceserver/db/img3.5.finished.faa.01 => yes
      def multipart_database_name?(db_name)
        !(db_name.match(/.+\/\S+\d{2}$/).nil?)
      end

    end

    def initialize(*args)
      args.last.downcase!
      args.each(&:freeze)
      super

      @id = Digest::MD5.hexdigest args.first
    end

    attr_reader :id

    def to_s
      "#{type}: #{title} #{name}"
    end
  end
end