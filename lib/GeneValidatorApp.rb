require 'GeneValidatorApp/GeneValidatorAppHelper.rb'
require 'bio'
require 'pathname'
require 'slim'
require 'sinatra/base'
require 'sinatra/config_file'

# The Actual App...
class GVapp < Sinatra::Base
  helpers GeneValidatorAppHelper

  configure do
    register Sinatra::ConfigFile
    config_file "#{Pathname.new(__FILE__).dirname.parent + 'config.yml'}"
  end

  before do
    @tempdir         = settings.tempdir
    @GVversion       = settings.GVversion
    @default_db      = settings.default_db
    @non_default_dbs = settings.non_default
    @dbs             = settings.dbs
    @unique_name     = create_unique_name

    # The Working directory is within the tempdir..
    @working_dir     = @tempdir + @unique_name
    puts @working_dir
    if File.exist?(@working_dir)
      @unique_name   = ensure_unique_name(@working_dir, @tempdir)
    end
    # The Public directory is written to the gem's public folder...
    @public_dir      = settings.root + 'public/GeneValidator' + @unique_name

    if File.exist?(@working_dir)
      fail IOError, 'A unique name cannot be created for this session.'
    end
    unless File.exist?(@tempdir)
      fail IOError, 'The Temporary folder cannot be found.'
    end
  end

  error do
    slim :"500", layout: false
  end

  get '/' do
    slim :index
  end

  post '/input' do
    seqs      = params[:seq]
    vals      = params[:validations].to_s.gsub(/[\[\]\"]/, '')
    db_title  = params[:database]
    # Extracts the db path using the db title
    db_path   = @dbs.select { |_, v| v[0][:title] == db_title }.keys[0]
    puts "Creating #{@working_dir}"
    
    FileUtils.mkdir_p @working_dir
    FileUtils.ln_s "#{@working_dir}", "#{@public_dir}"

    sequences = clean_sequences(seqs)
    seqs      = to_fasta(sequences)
    create_fasta_file(@working_dir, seqs)
    run_genevalidator(vals, db_path, seqs, @working_dir, @unique_name,
                      settings.mafft_path, settings.blast_path)
  end
end
