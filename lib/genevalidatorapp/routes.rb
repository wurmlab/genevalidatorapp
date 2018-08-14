require 'sinatra/base'
require 'sinatra/cross_origin'
require 'genevalidator/version'
require 'genevalidatorapp/version'
require 'slim'

module GeneValidatorApp
  # The Sinatra Routes
  class Routes < Sinatra::Base
    register Sinatra::CrossOrigin

    configure do
      # We don't need Rack::MethodOverride. Let's avoid the overhead.
      disable :method_override

      # Ensure exceptions never leak out of the app. Exceptions raised within
      # the app must be handled by the app. We do this by attaching error
      # blocks to exceptions we know how to handle and attaching to Exception
      # as fallback.
      disable :show_exceptions, :raise_errors

      # Make it a policy to dump to 'rack.errors' any exception raised by the
      # app so that error handlers don't have to do it themselves. But for it
      # to always work, Exceptions defined by us should not respond to `code`
      # or http_status` methods. Error blocks errors must explicitly set http
      # status, if needed, by calling `status` method.
      enable :dump_errors

      # We don't want Sinatra do setup any loggers for us. We will use our own.
      set :logging, nil

      # This is the app root...
      set :root,          -> { GeneValidatorApp.root }

      # This is the full path to the public folder...
      set :public_folder, -> { GeneValidatorApp.public_dir }
    end

    # Set up global variables for the templates...
    before '/' do
      @default_db         = Database.default_db
      @non_default_dbs    = Database.non_default_dbs
      @max_characters     = GeneValidatorApp.config[:max_characters]
      @current_gv_version = GeneValidator::VERSION
    end

    get '/' do
      slim :index
    end

    post '/' do
      cross_origin # Required for the API to work...
      RunGeneValidator.init(request.url, params)
      @gv_results = RunGeneValidator.run
      @json_data_section = @gv_results[:parsed_json]
      if @params[:results_url]
        @gv_results[:results_url]
      elsif @params[:json_url]
        @gv_results[:json_url]
      else
        slim :results, layout: false
      end
    end

    # This error block will only ever be hit if the user gives us a funny
    # sequence or incorrect advanced parameter. Well, we could hit this block
    # if someone is playing around with our HTTP API too.
    error RunGeneValidator::ArgumentError do
      status 400
      slim :"500", layout: false
    end

    # This will catch any unhandled error and some very special errors. Ideally
    # we will never hit this block. If we do, there's a bug in GeneValidatorApp
    # or something really weird going on.
    # TODO: If we hit this error block we show the stacktrace to the user
    # requesting them to post the same to our Google Group.
    error Exception, RunGeneValidator::RuntimeError do
      status 500
      slim :"500", layout: false
    end

    not_found do
      status 404
      slim :"500" # TODO: Create another Template
    end
  end
end
