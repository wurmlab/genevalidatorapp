require 'GeneValidatorApp/version'
require 'GeneValidatorApp/GeneValidatorApp_helpers'
require 'GeneValidatorApp/PreRunValidation.rb'
require 'fileutils'
require 'sinatra'
require 'slim'
require 'thin'
require 'sinatra/base'
require 'sinatra/config_file'

# The Actual App...
class GVapp < Sinatra::Base
  helpers GeneValidatorApp
  set :root, "#{File.dirname(__FILE__)}/../"
  register Sinatra::ConfigFile
  config_file "#{File.dirname(__FILE__)}/../config.yml"

  before do
    puts "\nStarting..."
    @tempdir       = settings.tempdir
    @default_db      = settings.default_db
    @non_default_dbs = settings.non_default

    @unique_name   = create_unique_name
    @working_dir   = File.join(@tempdir, @unique_name)
    if File.exist?(@working_dir)
      @unique_name = ensure_unique_name(@working_dir, @tempdir)
    end    
    @public_dir    = File.join("#{File.dirname(__FILE__)}", '..', 'public',
                               'GeneValidator', @unique_name)


    if File.exist?(@working_dir)
      halt 400, 'A unique name cannot be created for this session.'
    end
    unless File.exist?(@tempdir)
      halt 400, 'The Temporary folder cannot be found.'
    end
  end

  get '/' do
    slim :index
  end

  post '/input' do
    seqs = params[:seq]
    vals = params[:validations].to_s.gsub(/[\[\]\"]/, '')
    db   = params[:database]

    FileUtils.mkdir_p @working_dir
    FileUtils.ln_s "#{@working_dir}", "#{@public_dir}"
    seqs = to_fasta(seqs)
    create_fasta_file(@working_dir, seqs)
    run_genevalidator(vals, db, @working_dir, @unique_name)
  end
end