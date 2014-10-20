require 'GeneValidatorApp/GeneValidatorAppHelper.rb'
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

  error do
    slim :"500", layout: false
  end

  # Sert up variables for the templates
  before '/' do 
    @default_db      = settings.default_db
    @non_default_dbs = settings.non_default
    @GVversion       = settings.GVversion
  end

  get '/' do
    slim :index
  end

  # Run only when submitting a job to the server.
  before '/input' do
    @tempdir         = settings.tempdir
    @dbs             = settings.dbs
    @unique_name     = create_unique_name

    # Public Folder = folder that is served to the web app
    # By default, the folder is created in the Current Working Directory...
    @public_folder   = settings.public_folder + 'GeneValidator' + @unique_name

    # The Working directory created within the tempdir..
    @working_dir     = @tempdir + @unique_name
    if File.exist?(@working_dir)
      @unique_name   = ensure_unique_name(@working_dir, @tempdir)
    end
    
    FileUtils.mkdir_p @working_dir
    FileUtils.ln_s "#{@working_dir}", "#{@public_folder}"
  end

  post '/input' do
    seqs      = params[:seq]
    vals      = params[:validations].to_s.gsub(/[\[\]\"]/, '')
    db_title  = params[:database]
    # Extracts the db path using the db title
    db_path   = @dbs.select { |_, v| v[0][:title] == db_title }.keys[0]

    sequences = clean_sequences(seqs, @working_dir)
    run_genevalidator(vals, db_path, seqs, @working_dir, @unique_name,
                      settings.mafft_path, settings.blast_path)
  end
end
