require "GeneValidatorApp/version"


module GeneValidatorApp

  def create_results(insides)
      puts 'creating results'
      results = '<div id="results_box"><h2 class="page-header">Results</h2>'+ insides + '</div>'
      puts 'Returning results '
      return results
    end


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

  def run_genevalidator (validation_array, working_folder)

    puts 'Running Genevalidator from a sub-shell'
    command = "time Genevalidator -v \"#{validation_array}\" #{working_folder}/input_file.fa"
    exit = system(command)

    puts 'Checking the exit status.'
    if exit != true
      return "Sorry there has been a problem. The command exited with exit code:#{exit}."
    else
      puts ' Finished running the command sucessfully.'
    end

    html_table =  extract_table_html(working_folder)
    return html_table
  end

  def extract_table_html(working_folder)

    index_file = File.join(working_folder, "/input_file.fa.html", "index.html")

    raise error unless File.exist?(index_file)

    puts 'Reading the html output file...'
    full_html = IO.binread(index_file)
    cleanhtml = full_html.gsub(/[\n\t]/, '').gsub(/>\s*</, "><").gsub('  ',' ')

    cleanhtml.scan(/<div id="report">.*/) do |table|
      @html_table = table.gsub('</div></body></html>','')    # tYW instead modify GeneValidator. 
      #gsub name to full working dir path.. (to make the figures show...)
    end

    write_html_table(working_folder, @html_table)

    return @html_table
  end

  def write_html_table(working_folder, html_table)
    puts 'Writing the table to a file'
    File.open("#{working_folder}/table.html", 'w') do |f|
      f.write html_table
    end
  end
end
