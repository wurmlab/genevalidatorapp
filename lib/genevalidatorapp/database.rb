require 'find'
require 'digest/md5'
require 'forwardable'

module GeneValidatorApp
  # class on the BLAST databases
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

      def each(&block)
        all.each(&block)
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
        if config[:default_db] && Database.include?(config[:default_db])
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
        cmd  = "blastdbcmd -recursive -list #{database_dir} -list_outfmt" \
               ' "%p::%f::%t"'
        list = `#{cmd} 2>&1`
        list.each_line do |line|
          type, name, title = line.split('::', 3)
          next if name.nil?
          next if multipart_database_name?(name)
          next unless type.casecmp('protein').zero?
          self << Database.new(name, title, type)
        end
      end

      # Returns true if the database name appears to be a multi-part database
      # name.
      #
      # e.g.
      # /home/ben/pd.ben/sequenceserver/db/nr.00 => yes
      # /home/ben/pd.ben/sequenceserver/db/nr => no
      # /home/ben/pd.ben/sequenceserver/db/img3.5.finished.faa.01 => yes
      def multipart_database_name?(db_name)
        !db_name.match(%r{.+\/\S+\d{2}$}).nil?
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
