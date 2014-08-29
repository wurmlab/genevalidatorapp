require "GeneValidatorApp/version"
require 'fileutils'


module GeneValidatorApp

  def create_results(insides)
    results = '<div id="results_box"><h2 class="page-header">Results</h2>'+ insides + '</div>'
    return results
  end

  def create_unique_name
    unique_name = Time.new.strftime('%Y-%m-%d_%H-%M-%S-%L-%N') + '_' + request.ip.gsub('.','-')
    return unique_name
  end

  # def ensure_unique_name(public_folder)
  #   while File.exist?(public_folder)
  #     unique_name    = create_unique_name
  #     working_folder = File.join(Dir.home + '/Genevalidator/' + unique_name)
  #     public_folder  = File.join("#{File.dirname(__FILE__)}", '/../public/Genevalidator', unique_name)
  #   end
  # end

  def to_fasta(sequence)
    sequence = sequence.lstrip
    unique_queries = Hash.new()
    if sequence[0,1] != '>'
      sequence.insert(0, ">Submitted at #{Time.now.strftime('%H:%M, %A, %B %d, %Y')}\n")
    end
    sequence.gsub!(/^\>(\S+)/) do |s|
      if unique_queries.has_key?(s)
        unique_queries[s] += 1
        s + '_' + (unique_queries[s]-1).to_s
      else
        unique_queries[s] = 1
        s
      end
    end
    return sequence
  end

  def run_genevalidator (validation_array, working_folder, public_folder, unique_name)
    index_folder = File.join(working_folder, 'input_file.fa.html')

    puts 'Running Genevalidator from a sub-shell'
    command = "time Genevalidator -v \"#{validation_array}\" #{working_folder}/input_file.fa"
    exit = system(command)
    raise IOError("Genevalidator exited with the command code: #{exit}") unless exit

    html_table = extract_table_html(working_folder, public_folder, unique_name)
    
    return html_table
  end

  def extract_table_html(working_folder, public_folder, unique_name)
    index_file = File.join(working_folder, "/input_file.fa.html", "index.html")
    raise IOError("GeneValidator has not created any results files...") unless File.exist?(index_file)

    puts 'Reading the html output file...'
    full_html = IO.binread(index_file)
    cleanhtml = full_html.gsub(/>\s*</, "><").gsub(/[\t\n]/, '').gsub('  ', ' ')
    cleanhtml.scan(/<div id="report">.*/) do |table|
      @html_table = table.gsub('</div></body></html>','').gsub(/input_file.fa_/, File.join('Genevalidator', unique_name, 'input_file.fa_'))  # tYW instead modify GeneValidator. 
    end

    copy_json_plots(working_folder, public_folder)
    write_html_table(public_folder, @html_table)

    return @html_table
  end

  def write_html_table(public_folder, html_table)
    puts 'Writing the table to a file'
    File.open("#{public_folder}/table.html", 'w') do |f|
      f.write html_table
    end
  end

  def copy_json_plots(working_folder, public_folder)
    puts "copying Json files"
    json_files = File.join(working_folder, "/input_file.fa.html", "*.json")
    FileUtils.cp_r Dir.glob(json_files), public_folder
  end
end
